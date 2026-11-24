classdef BridgeConditionApp < handle
    %BRIDGECONDITIONAPP MATLAB app for the CE 7405 equivalent-beam bridge analysis (MATLAB-style colours).
    %   APP = BRIDGECONDITIONAPP() opens the app window. It is a code-built
    %   app: the same components App Designer uses (UIFIGURE, UIGRIDLAYOUT,
    %   UITAB, UIAXES, ...) written as plain text (DECISIONS.md D-023).
    %   There are no calculations in the app. Every number comes from the
    %   verified engine in src/ (buildModelFromTables, prepareMovingLoad,
    %   analyzeVehiclePosition, runMovingLoad, solveStaticModel), and every
    %   drawing from the tested bridgeDrawing and responseDiagramData.
    %
    %   Tabs:
    %     Bridge model         unit system (SI or US customary), span table,
    %                          supports A, B, C ... (Pin / Roller / Fixed /
    %                          Free), steel Es*Is or RCC Ec*Ieff, permanent
    %                          uniform load; drawing with conventional supports
    %     Vehicle & moving load axles and spacings, position slider; truck
    %                          schematic, deformed shape (stated magnification),
    %                          M, V and v diagrams, reactions at that position
    %     Envelopes            quasi-static crossing: max/min M, V, v envelopes,
    %                          critical vehicle positions, reaction envelopes
    %     Damage (Stage 2)     prescribed EI loss EI_D = (1 - d) EI on a region;
    %                          healthy vs damaged envelopes and reactions; a
    %                          sensitivity sweep moving the same loss along the beam
    %     Identification (Stage 3) sensor and truck-position tables and deflection
    %                          readings (synthetic test case or entered); single-
    %                          region inverse search with a noise-based region of
    %                          uncertainty; fit by location, candidates, residuals
    %     Matrices             k_e, global K, DOF status, F, U and R at the
    %                          current vehicle position (computational transparency)
    %     Verification         runs the automated test suite and shows its summary
    %
    %   The public methods below are also what tests/gui/checkBridgeConditionApp.m
    %   calls to check the app against the engine.
    %   Analysis limits (PROJECT_SPEC.md section 1): 2D equivalent beam,
    %   linear elastic, quasi-static. This is not a load rating or a design tool.
    %
    %   Example:
    %     addProjectPaths;
    %     app = BridgeConditionApp;
    %
    %   Information boxes are formatted HTML (UIHTML, INFOPANELHTML).
    %
    %   See also BUILDMODELFROMTABLES, RUNMOVINGLOAD, BRIDGEDRAWING, INFOPANELHTML.

    properties (SetAccess = private)
        UIFigure                  % app window
        Controls = struct()       % handles of all input and output components
        Model = []                % current beam model (createBeamModel struct)
        ModelInfo = []            % summary, warnings, support letters and x from buildModelFromTables
        Units = []                % display unit system (unitSystem): every input and result is shown in it
        Vehicle = []              % current vehicle (createVehicle struct)
        Direction = 1             % +1 toward +x, -1 toward -x
        Step = 0.1                % position step [m] (actual, from generateVehiclePositions)
        Prep = []                 % prepareMovingLoad result for the current model
        Position = 0              % current front-axle position x_v [m]
        PositionResult = []       % analyzeVehiclePosition result at Position
        MovingLoad = []           % runMovingLoad result, empty until the Envelopes tab is run
        StaticResult = []         % solveStaticModel result shown on the Matrices tab
        LastError = ''            % message of the last input or analysis error ('' if none)
        DamagedModel = []         % Model with the prescribed stiffness loss of the Damage tab (Stage 2)
        DamageComparison = []     % compareHealthyDamaged result
        DamageSensitivity = []    % damageSensitivity result
        IdentTruth = []           % hidden case of the synthetic readings (Stage 3), [] for entered readings
        IdentResult = []          % identifySingleDamage result
    end

    properties (Access = private)
        Theme
        PositionRange = [0 1]
        DirectionItems = {'+x (left to right)', '-x (right to left)'}
        ReadingsSetup = []        % sensors and positions [m] the readings table was made for
        NodeX = []                % node coordinates [m] behind the region drop-downs
        SupportNodes = []         % node index of each entry of the support drop-down (Damage tab)
        UnitMemory = []           % inputs before and after the last unit switch (exact switch back)
        Previewing = false        % the Bridge model tab shows a preview of un-applied table edits
    end

    methods
        function app = BridgeConditionApp()
            if exist('createBeamModel', 'file') ~= 2
                root = fileparts(fileparts(mfilename('fullpath')));
                addpath(root);
                addProjectPaths();
            end
            app.Theme = appTheme();
            app.Units = unitSystem('SI');
            app.createComponents();
            app.onPresetChanged();               % fill the axle table from the first preset
            app.applyModelInputs();
            app.applyVehicleInputs();
        end

        function delete(app)
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end

        function ok = applyModelInputs(app)
            %APPLYMODELINPUTS Build the model from the Bridge model tab (button "Apply model").
            c = app.Controls;
            in = app.modelTableInputs();
            try
                [model, info] = buildModelFromTables(in, app.Units);
            catch err
                ok = app.reportError(err, 'Model input');
                return
            end
            app.Model = model;
            app.ModelInfo = info;
            app.MovingLoad = [];
            app.StaticResult = [];
            app.LastError = '';
            c.SummaryArea.HTMLSource = infoPanelHtml('model', info.summary);
            app.Previewing = false;
            app.drawModelTab();
            if ~isempty(info.warnings)
                uialert(app.UIFigure, strjoin(info.warnings, ' '), 'Check units', 'Icon', 'warning');
            end
            ok = true;
            if ~isempty(app.Vehicle)
                ok = app.resetMovingLoad();
            end
            app.refreshSupportsTable();
            app.refreshRegionChoices();
            app.clearEnvelopes();
            app.clearDamage();
            app.resetIdentification();
            app.setStatus(sprintf('Model applied: %s', info.summary{1}));
        end

        function ok = applyVehicleInputs(app)
            %APPLYVEHICLEINPUTS Build the vehicle from the Vehicle tab (button "Apply vehicle").
            c = app.Controls;
            U = app.Units;
            try
                vehicle = app.vehicleInput(U);
            catch err
                ok = app.reportError(err, 'Vehicle input');
                return
            end
            app.Vehicle = vehicle;
            app.Step = c.StepField.Value * U.length.toSI;
            app.Direction = 1;
            if strcmp(c.DirectionDropDown.Value, app.DirectionItems{2})
                app.Direction = -1;
            end
            app.MovingLoad = [];
            app.LastError = '';
            app.clearEnvelopes();
            app.clearDamageResults();
            if ~isempty(app.Model)
                % Truck positions and readings depend on the vehicle and direction; sensors and the
                % hidden-case inputs are the user's and stay.
                [~, positions] = identificationDefaults(app.Model, app.Vehicle, app.Direction);
                app.setPointTable(c.PositionsTable, positions / U.length.toSI, 'P');
                app.clearIdentificationReadings();
            end
            ok = true;
            if ~isempty(app.Model)
                ok = app.resetMovingLoad();
            end
            if ok && isempty(app.LastError)            % keep an error reported while placing the vehicle
                app.setStatus(sprintf('Vehicle applied: %s, %d axle(s), total %g %s.', vehicle.name, ...
                    numel(vehicle.axleLoads), sum(vehicle.axleLoads) / U.force.toSI, U.force.unit));
            end
        end

        function setVehiclePosition(app, xv)
            %SETVEHICLEPOSITION Analyse and show the vehicle with its front axle at XV [m].
            if isempty(app.Prep) || isempty(app.Vehicle)
                return
            end
            xv = min(max(xv, app.PositionRange(1)), app.PositionRange(2));
            try
                res = analyzeVehiclePosition(app.Prep, app.Vehicle, xv, app.Direction);
            catch err
                app.reportError(err, 'Analysis');
                return
            end
            app.Position = xv;
            app.PositionResult = res;
            c = app.Controls;
            U = app.Units;
            c.PositionSlider.Value = min(max(xv / U.length.toSI, c.PositionSlider.Limits(1)), c.PositionSlider.Limits(2));
            c.PositionLabel.Text = sprintf('x_v = %.3f %s (front axle, measured from A); %d of %d axles on the bridge', ...
                xv / U.length.toSI, U.length.unit, nnz(res.axles.onBridge), numel(res.axles.x));
            app.drawPositionView();
            [data, columns] = currentReactionTableData(res, app.Model, U);
            c.ReactionsTable.Data = data;
            c.ReactionsTable.ColumnName = regexprep(columns, ' \(\+ (up|CCW)\)$', '');   % signs in the label above
        end

        function stepVehicle(app, nSteps)
            %STEPVEHICLE Move the vehicle NSTEPS position steps in its travel direction.
            app.setVehiclePosition(app.Position + nSteps * app.Direction * app.Step);
        end

        function ok = runEnvelopes(app)
            %RUNENVELOPES Move the vehicle across the bridge and show envelopes (button on the Envelopes tab).
            ok = false;
            if isempty(app.Model) || isempty(app.Vehicle)
                return
            end
            dlg = uiprogressdlg(app.UIFigure, 'Title', 'Moving-load analysis', ...
                'Message', 'Moving the vehicle across the bridge (quasi-static positions)...', 'Indeterminate', 'on');
            closer = onCleanup(@() close(dlg));
            try
                ml = runMovingLoad(app.Model, app.Vehicle, 'Step', app.Step, 'Direction', app.Direction);
            catch err
                ok = app.reportError(err, 'Moving-load analysis');
                return
            end
            app.MovingLoad = ml;
            app.LastError = '';
            app.drawEnvelopes();
            app.setStatus(sprintf('Envelopes: %d positions (step %.4g %s) + %d refined positions.', ...
                ml.nCoarse, ml.step / app.Units.length.toSI, app.Units.length.unit, ml.nRefined));
            ok = true;
        end

        function ok = showMatrices(app)
            %SHOWMATRICES Fill the Matrices tab from a static solve at the current vehicle position.
            ok = false;
            if isempty(app.Model)
                return
            end
            model = app.Model;
            if ~isempty(app.Vehicle)
                model = modelWithVehicle(model, app.Vehicle, app.Position, app.Direction);
            end
            try
                res = solveStaticModel(model);
            catch err
                ok = app.reportError(err, 'Static solution');
                return
            end
            app.StaticResult = res;
            c = app.Controls;
            ne = size(model.elements.conn, 1);
            nn = numel(model.nodes.x);
            c.ElementSpinner.Limits = [1, max(ne, 2)];
            e = min(round(c.ElementSpinner.Value), ne);
            c.ElementSpinner.Value = e;
            labels = dofLabels(nn);
            dofs = elementDofs(model.elements.conn(e, :));
            c.KeTable.Data = formatMatrixCells(res.ke(:, :, e), '%.6g');
            c.KeTable.ColumnName = labels(dofs);
            c.KeTable.RowName = labels(dofs);
            c.KTable.Data = formatMatrixCells(res.K, '%.4g');
            c.KTable.ColumnName = labels;
            c.KTable.RowName = labels;
            nDof = 2 * nn;
            dofData = cell(nDof, 7);
            isRestrained = false(nDof, 1);
            isRestrained(res.restrainedDofs) = true;
            for k = 1:nDof
                status = 'free';
                if isRestrained(k)
                    status = 'restrained';
                end
                dofData(k, :) = {labels{k}, sprintf('%d', ceil(k/2)), sprintf('%.4g', model.nodes.x(ceil(k/2))), status, ...
                    sprintf('%.6g', res.F(k)), sprintf('%.6g', res.U(k)), sprintf('%.6g', res.R(k))};
            end
            c.DofTable.Data = dofData;
            c.DofTable.ColumnName = {'DOF', 'Node', 'x [m]', 'Status', 'F [N or N*m]', 'U [m or rad]', 'R [N or N*m]'};
            Le = model.nodes.x(e + 1) - model.nodes.x(e);
            EIeff = effectiveEI(model);       % includes any prescribed stiffness loss
            c.MatrixInfo.Text = sprintf(['Element %d: L_e = %.4g m, EI = %.6g N*m^2.  %d DOFs: %d free, %d restrained.  ' ...
                'rcond(Kff) = %.3g.  Loads: permanent + vehicle at x_v = %.3f m.  Units: N, m, rad.'], ...
                e, Le, EIeff(e), nDof, numel(res.freeDofs), numel(res.restrainedDofs), ...
                res.diagnostics.rcondKff, app.Position);
            ok = true;
        end

        function ok = applyDamageInputs(app)
            %APPLYDAMAGEINPUTS Apply the Damage tab's loss to the healthy model (button "Apply damage").
            c = app.Controls;
            try
                app.checkRegionOrder(c.DamageFromDropDown, c.DamageToDropDown, 'Damaged region');
                [damaged, elements] = damageModelFromInputs(app.Model, app.selectedNodeX(c.DamageFromDropDown), ...
                    app.selectedNodeX(c.DamageToDropDown), c.LossField.Value);
            catch err
                ok = app.reportError(err, 'Damage input');
                return
            end
            app.DamagedModel = damaged;
            app.LastError = '';
            app.clearDamageResults();
            app.drawDamageModel();
            d = c.LossField.Value / 100;
            summary = sprintf('Elements %d-%d, %s to %s: EI_D = (1 - %.4g) EI = %.4g EI', min(elements), max(elements), ...
                c.DamageFromDropDown.Value, c.DamageToDropDown.Value, d, 1 - d);
            c.DamageInfo.HTMLSource = infoPanelHtml('damage', {summary; ...
                'd reduces MODEL flexural rigidity; it is not a percentage of corrosion, section loss or capacity.'});
            app.setStatus(['Damage applied: ' summary]);
            ok = true;
        end

        function clearDamage(app)
            %CLEARDAMAGE Remove the prescribed loss (button "Clear damage"); the healthy model is unchanged.
            app.DamagedModel = [];
            app.clearDamageResults();
            if ~isempty(app.Model)
                app.drawDamageModel();
            end
            app.Controls.DamageInfo.HTMLSource = infoPanelHtml('message', ...
                {'No damage applied. Choose a region on nodes and a loss d, then press Apply damage.'});
        end

        function ok = runDamageComparison(app)
            %RUNDAMAGECOMPARISON Healthy vs damaged moving-load results (button "Compare healthy vs damaged").
            ok = false;
            if isempty(app.DamagedModel) || isempty(app.Vehicle)
                % A reminder, not an analysis error: nothing is computed and LastError is kept.
                msg = 'No damage is applied yet: press "Apply damage" first.';
                app.setStatus(msg);
                uialert(app.UIFigure, msg, 'Healthy vs damaged', 'Icon', 'info');
                return
            end
            dlg = uiprogressdlg(app.UIFigure, 'Title', 'Healthy vs damaged', ...
                'Message', 'Moving the vehicle across the healthy and the damaged bridge...', 'Indeterminate', 'on');
            closer = onCleanup(@() close(dlg));
            try
                cmp = compareHealthyDamaged(app.Model, app.DamagedModel, app.Vehicle, 'Step', app.Step, ...
                    'Direction', app.Direction);
            catch err
                ok = app.reportError(err, 'Damage comparison');
                return
            end
            app.DamageComparison = cmp;
            app.LastError = '';
            c = app.Controls;
            th = app.Theme;
            U = app.Units;
            h = cmp.healthy.envelope;
            d = cmp.damaged.envelope;
            x = cmp.stations / U.length.toSI;
            xl = sprintf('x [%s]', U.length.unit);
            m = U.moment.toSI;
            f = U.force.toSI;
            v = U.deflection.toSI;
            healthy = [th.healthyMax; th.healthyMin];   % colours: max, min
            damaged = [th.damagedMax; th.damagedMin];
            plotEnvelopeComparison(c.DamageMomentAxes, x, h.Mmax / m, h.Mmin / m, d.Mmax / m, d.Mmin / m, ...
                healthy, damaged, sprintf('M [%s]', U.moment.unit), 'Moment envelope', xl);
            plotEnvelopeComparison(c.DamageShearAxes, x, h.Vmax / f, h.Vmin / f, d.Vmax / f, d.Vmin / f, ...
                healthy, damaged, sprintf('V [%s]', U.force.unit), 'Shear envelope', xl);
            plotEnvelopeComparison(c.DamageDeflectionAxes, x, h.vmax / v, h.vmin / v, d.vmax / v, d.vmin / v, ...
                healthy, damaged, sprintf('v [%s]', U.deflection.unit), 'Deflection envelope', xl);
            [data, columns] = damageComparisonTableData(cmp, U);
            c.DamageTable.Data = data;
            c.DamageTable.ColumnName = columns;
            c.DamageFindings.HTMLSource = infoPanelHtml('findings', damageComparisonSummary(cmp, app.Model, U));
            c.DamageResultTabs.SelectedTab = c.DamageCompareTab;
            app.setStatus(sprintf(['Healthy vs damaged: %d positions per model. Healthy: blue (max), light blue (min); ' ...
                'damaged: dark red (max), orange (min).'], ...
                numel(cmp.healthy.positions)));
            ok = true;
        end

        function ok = runDamageSensitivity(app)
            %RUNDAMAGESENSITIVITY Move the same loss over every element and rank the influence (button "Run sensitivity").
            ok = false;
            c = app.Controls;
            if isempty(app.Model) || isempty(app.Vehicle)
                return
            end
            try
                code = sensitivityQuantityCode(c.SensitivityDropDown.Value);
                d = c.LossField.Value / 100;
                opts = {'Step', max(app.Step, c.SensitivityStepField.Value * app.Units.length.toSI), ...
                    'Direction', app.Direction, 'Refine', false};
                if strcmp(code, 'Rmax')
                    opts = [opts, {'Node', app.selectedSupportNode()}];
                end
                dlg = uiprogressdlg(app.UIFigure, 'Title', 'Sensitivity sweep', ...
                    'Message', 'Moving the loss along the beam, one element at a time...', 'Indeterminate', 'on');
                closer = onCleanup(@() close(dlg));
                s = damageSensitivity(app.Model, app.Vehicle, d, code, opts{:});
            catch err
                ok = app.reportError(err, 'Sensitivity sweep');
                return
            end
            app.DamageSensitivity = s;
            app.LastError = '';
            plotSensitivity(c.SensitivityAxes, s, app.Model, app.Theme.damage, app.Units);
            [data, columns] = sensitivityTableData(s, app.Model, app.Units);
            c.SensitivityTable.Data = data;
            c.SensitivityTable.ColumnName = columns;
            c.DamageResultTabs.SelectedTab = c.DamageSensitivityTab;
            scale = app.responseScale(code);              % a physical size: round-off is far below it
            [~, restrained] = partitionDofs(app.Model);
            determinate = numel(restrained) == 2 && code(1) ~= 'v';   % M, V, R from equilibrium alone
            if max(abs([s.healthy; s.values(:)])) <= 1e-9 * scale
                % e.g. the hogging moment of a simple span: the response is zero, its changes are round-off
                data(:, end) = {'n/a'};
                c.SensitivityTable.Data = data;
                app.setStatus(sprintf(['Sensitivity: d = %g %% moved over %d locations; the response is zero for every ' ...
                    'location (e.g. no hogging moment on a simply supported span).'], 100 * d, numel(s.groups)));
            elseif determinate
                % Decided from the supports, not from the size of the changes: their round-off grows with the
                % number of elements (about 3e-8 of the response with 600 elements on one span).
                app.setStatus(sprintf(['Sensitivity: d = %g %% moved over %d locations; the response is the same for every ' ...
                    'location (M, V and R of a statically determinate beam do not depend on EI; any change shown ' ...
                    'is round-off).'], 100 * d, numel(s.groups)));
            elseif max(abs(s.change)) <= 1e-9 * scale
                % an indeterminate beam whose extreme happens not to depend on EI (e.g. it lies on an overhang)
                app.setStatus(sprintf(['Sensitivity: d = %g %% moved over %d locations; the response is the same for every ' ...
                    'location (it does not depend on EI here).'], 100 * d, numel(s.groups)));
            else
                app.setStatus(sprintf('Sensitivity: d = %g %% moved over %d locations; most influential: element(s) %s.', ...
                    100 * d, numel(s.groups), data{1, 2}));
            end
            ok = true;
        end

        function ok = generateSyntheticReadings(app)
            %GENERATESYNTHETICREADINGS Readings of a hidden damage case (button "Generate synthetic readings").
            c = app.Controls;
            try
                [sensors, positions] = app.identificationSetup();
                app.checkRegionOrder(c.HiddenFromDropDown, c.HiddenToDropDown, 'Hidden region');
                [uObs, truth] = syntheticObservations(app.Model, app.Vehicle, positions, sensors, app.Direction, ...
                    app.selectedNodeX(c.HiddenFromDropDown), app.selectedNodeX(c.HiddenToDropDown), ...
                    c.HiddenLossField.Value, c.SyntheticNoiseField.Value, round(c.SeedField.Value));
            catch err
                ok = app.reportError(err, 'Synthetic readings');
                return
            end
            app.setReadingsTable(uObs, sensors, positions);
            app.IdentTruth = truth;
            app.LastError = '';
            c.IdentInfo.HTMLSource = infoPanelHtml('message', ...
                {'Synthetic readings generated. The hidden case is kept from the search and shown only afterwards.'; ...
                'Press "Run identification".'});
            app.setStatus(sprintf('%d synthetic readings (%d sensors x %d truck positions).', numel(uObs), ...
                numel(sensors), numel(positions)));
            ok = true;
        end

        function ok = newEmptyReadings(app)
            %NEWEMPTYREADINGS Empty readings table for measured deflections (button "New empty table").
            try
                [sensors, positions] = app.identificationSetup();
            catch err
                ok = app.reportError(err, 'Readings table');
                return
            end
            app.setReadingsTable(NaN(numel(sensors), numel(positions)), sensors, positions);
            app.IdentTruth = [];
            app.LastError = '';
            app.Controls.IdentInfo.HTMLSource = infoPanelHtml('message', ...
                {sprintf(['Type the measured vehicle-only deflections [%s] (downward negative), ' ...
                'one row per sensor and one column per truck position. A cell left at NaN is a missing reading.'], ...
                app.Units.deflection.unit)});
            ok = true;
        end

        function ok = runIdentification(app)
            %RUNIDENTIFICATION Single-region inverse search on the readings table (button "Run identification").
            ok = false;
            c = app.Controls;
            try
                [sensors, positions] = app.identificationSetup();
                if isempty(app.ReadingsSetup) || ~isequal(app.ReadingsSetup.sensors, sensors) || ...
                        ~isequal(app.ReadingsSetup.positions, positions)
                    error('BridgeFE:invalidInput', ['Sensors or truck positions differ from those of the readings ' ...
                        'table: press "Generate synthetic readings" or "New empty table" first.']);
                end
                uObs = readingsFromTable(c.ReadingsTable.Data, numel(sensors), numel(positions), app.Units);
            catch err
                ok = app.reportError(err, 'Identification input');
                return
            end
            if all(isnan(uObs(:)))
                msg = 'The readings table is empty: generate synthetic readings or type measured deflections first.';
                app.setStatus(msg);
                uialert(app.UIFigure, msg, 'Identification', 'Icon', 'info');
                return
            end
            try
                app.checkZeroReadings(sensors, positions, uObs);
                opts = identificationOptions(app.Model, candidateRegionLength(c.RegionSizeDropDown.Value, app.Units), ...
                    c.SearchNoiseField.Value, c.SearchNoiseAbsField.Value, app.Direction, app.Units);
                dlg = uiprogressdlg(app.UIFigure, 'Title', 'Identification', ...
                    'Message', 'Analysing every candidate region and loss...', 'Indeterminate', 'on');
                closer = onCleanup(@() close(dlg));
                result = identifySingleDamage(app.Model, app.Vehicle, positions, sensors, uObs, opts{:});
            catch err
                ok = app.reportError(err, 'Identification');
                return
            end
            app.IdentResult = result;
            app.LastError = '';
            th = app.Theme;
            U = app.Units;
            plotFitProfile(c.FitAxes, fitProfileData(result, app.Model, U), app.Model.nodes.x / U.length.toSI, th, U);
            [data, columns] = identificationTableData(result, U);
            c.CandidateTable.Data = data;
            c.CandidateTable.ColumnName = columns;
            plotReadings(c.ReadingsAxes, positions, sensors, uObs, result.uHealthy, result.best.u, th, U);
            [summary, flags] = identificationSummary(result, app.IdentTruth, U);
            c.IdentResultText.HTMLSource = infoPanelHtml('identSummary', summary, flags);
            c.IdentInfo.HTMLSource = infoPanelHtml('identBox', [summary(2); flags; {'Full result: "Summary" tab.'}], flags);
            app.drawIdentification();
            c.IdentResultTabs.SelectedTab = c.IdentFitTab;
            app.setStatus(sprintf('Identification: %d structures analysed; %d candidate region(s) in the region of uncertainty.', ...
                result.nStructures, numel(result.competing)));
            ok = true;
        end

        function onSpansEdited(app)
            app.refreshSupportsTable();
            app.previewModel();
        end

        function addSpan(app)
            %ADDSPAN Append a span like the last one (button "+ Add span").
            c = app.Controls;
            spans = c.SpansTable.Data;
            farEnd = c.SupportsTable.Data{end, 3};
            c.SpansTable.Data = [spans; spans(end, :)];
            app.refreshSupportsTable();
            data = c.SupportsTable.Data;                 % the far-end support moves to the new far end;
            data(end-1:end, 3) = {'Roller'; farEnd};     % the old end becomes an interior roller
            c.SupportsTable.Data = data;
            app.previewModel();
        end

        function removeSpan(app)
            %REMOVESPAN Remove the last span (button "- Remove last span").
            c = app.Controls;
            spans = c.SpansTable.Data;
            if size(spans, 1) < 2
                app.setStatus('A bridge needs at least one span.');
                return
            end
            farEnd = c.SupportsTable.Data{end, 3};
            c.SpansTable.Data = spans(1:end-1, :);
            app.refreshSupportsTable();
            if ~strcmpi(farEnd, 'Free')                  % keep a far-end support (e.g. Fixed); a free tip is
                c.SupportsTable.Data{end, 3} = farEnd;   % not moved onto the last support (it would be lost)
            end
            app.previewModel();
        end

        function onAxlesEdited(app)
            c = app.Controls;
            c.PresetDropDown.Value = 'Custom';
            presets = vehiclePresets(app.Units);
            c.PresetNote.Text = presets(strcmp({presets.name}, 'Custom')).note;
            app.updateAxleTotal();
            app.setStatus(app.vehicleEditedText());
        end

        function text = vehicleEditedText(~)
            text = 'Vehicle edited: press "Apply vehicle" to use it (the drawing shows the applied vehicle).';
        end

        function addAxle(app)
            %ADDAXLE Append an axle like the last one, 1.2 m behind it (button "+ Add axle").
            c = app.Controls;
            data = c.AxlesTable.Data;
            loads = app.tableNumbers(data, 1);
            spacings = app.tableNumbers(data(1:end-1, :), 2);
            app.setAxleTable([loads, loads(end)], [spacings, 1.2 / app.Units.length.toSI]);
            app.onAxlesEdited();
        end

        function removeAxle(app)
            %REMOVEAXLE Remove the last axle (button "- Remove last axle").
            c = app.Controls;
            data = c.AxlesTable.Data;
            if size(data, 1) < 2
                app.setStatus('A vehicle needs at least one axle.');
                return
            end
            loads = app.tableNumbers(data, 1);
            spacings = app.tableNumbers(data(1:end-1, :), 2);
            app.setAxleTable(loads(1:end-1), spacings(1:end-1));
            app.onAxlesEdited();
        end

        function addIdentPoint(app, kind)
            %ADDIDENTPOINT Add a sensor ('sensor') or truck position ('truck position') (buttons "+ Add").
            %   The new entry is the first of these that gives non-zero readings and is not in the table yet:
            %   one spacing after the last entry (in the travel direction for truck positions), halfway
            %   from the last entry to the end of the range, or the middle of the largest gap (supports
            %   count as gap ends for sensors). A sensor on a support, or a truck position with no axle
            %   inside a span, would read zero, and the search cannot use it.
            [tbl, prefix, limits] = app.identPointTable(kind);
            v = app.tableNumbers(tbl.Data, 1);
            given = v(~isnan(v));
            dir = 1;
            if strcmp(kind, 'truck position')
                dir = app.Direction;
            end
            span = limits(2) - limits(1);
            ends = limits;
            if dir < 0
                ends = fliplr(limits);
            end
            candidates = [];
            if ~isempty(given)
                last = given(end);
                step = span / 4;
                if numel(given) >= 2 && given(end) ~= given(end - 1)
                    step = abs(given(end) - given(end - 1));
                end
                candidates = [last + dir * step, (last + ends(2)) / 2];
            end
            marks = sort([limits, given]);
            if strcmp(kind, 'sensor')
                marks = sort([marks, app.ModelInfo.supportX(:)' / app.Units.length.toSI]);
            end
            gaps = diff(marks);
            [~, order] = sort(gaps + 1e-9 * (1:numel(gaps)) / numel(gaps), 'descend');   % ties: the rightmost gap
            candidates = [candidates, (marks(order) + marks(order + 1)) / 2];
            tol = 1e-9 * max(span, 1);
            % The new entry is shown with 6 digits, which may move it by up to 5e-6 of its value: an entry
            % that close to a table entry repeats it, and a sensor that close to a support (e.g. 65.6168 ft
            % for a support at 65.6167979 ft) reads almost nothing.
            near = 1e-5 * max(abs(limits)) + tol;
            taken = given;
            if strcmp(kind, 'sensor')
                taken = [taken, app.ModelInfo.supportX(:)' / app.Units.length.toSI];
            end
            next = NaN;
            for k = 1:numel(candidates)
                x = str2double(sprintf('%.6g', candidates(k)));
                if x > limits(1) + tol && x < limits(2) - tol && all(abs(taken - x) > near) ...
                        && app.readsSomething(kind, x)
                    next = x;
                    break
                end
            end
            if isnan(next)
                app.setStatus(sprintf('No room for another %s: type its value into the table instead.', kind));
                return
            end
            app.setPointTable(tbl, [v, next], prefix);
            try
                scroll(tbl, 'bottom');                      % show the new row (MATLAB R2021b and later)
            catch
            end
            app.onIdentPointsEdited();
        end

        function removeIdentPoint(app, kind)
            %REMOVEIDENTPOINT Remove the last sensor or truck position (buttons "- Remove"); at least one stays.
            [tbl, prefix, ~, noun] = app.identPointTable(kind);
            v = app.tableNumbers(tbl.Data, 1);
            if numel(v) < 2
                app.setStatus(sprintf('At least one %s is needed.', noun));
                return
            end
            app.setPointTable(tbl, v(1:end-1), prefix);
            app.onIdentPointsEdited();
        end

        function setUnitSystem(app, name)
            %SETUNITSYSTEM Switch the display units to 'SI' or 'US' (as the unit-system drop-down does).
            U = unitSystem(name);
            app.Controls.UnitsDropDown.Value = U.label;
            app.onUnitsChanged();
        end

        function choosePreset(app, name)
            %CHOOSEPRESET Fill the axle table from a vehicle preset (as the preset drop-down does).
            app.Controls.PresetDropDown.Value = name;
            app.onPresetChanged();
        end

        function output = runVerification(app)
            %RUNVERIFICATION Run the automated test suite (runAllTests) and show its output.
            c = app.Controls;
            c.VerificationArea.Value = {'Running all tests ...'};
            drawnow;
            output = evalc('try, runAllTests; catch verificationError, disp(verificationError.message); end');
            lines = regexp(output, '\r?\n', 'split');
            c.VerificationArea.Value = lines(:);
            summary = lines(~cellfun(@isempty, regexp(lines, '^Total:', 'once')));
            if ~isempty(summary)
                app.setStatus(['Verification: ' summary{end}]);
            end
        end
    end

    methods (Access = private)
        function ok = resetMovingLoad(app)
            ok = false;
            try
                app.Prep = prepareMovingLoad(app.Model, defaultEnvelopeStations(app.Model.nodes.x, 4));
                [xv, step] = generateVehiclePositions(app.Model, app.Vehicle, app.Step, app.Direction);
            catch err
                app.Prep = [];
                ok = app.reportError(err, 'Moving-load setup');
                return
            end
            app.Step = step;
            app.PositionRange = [min(xv), max(xv)];
            s = app.Controls.PositionSlider;
            s.Limits = app.PositionRange / app.Units.length.toSI;     % the slider works in display length
            s.MajorTicks = app.sliderTicks(s.Limits);   % round values; the crossing end is not labelled
            s.Value = xv(1) / app.Units.length.toSI;
            app.setVehiclePosition(xv(1));
            ok = true;
        end

        function ticks = sliderTicks(~, limits)
            % Round slider ticks inside LIMITS: steps of 1, 2 or 5 x 10^k, 4 to 10 intervals, so 3-digit
            % labels stay apart on a restored window too. MATLAB's automatic ticks also label the limits,
            % which collides with the last round tick ("120126.4").
            raw = (limits(2) - limits(1)) / 10;
            steps = [1 2 5 10] * 10 ^ floor(log10(raw));
            step = steps(find(steps >= raw * (1 - 1e-12), 1));
            ticks = (ceil(limits(1) / step - 1e-9):floor(limits(2) / step + 1e-9)) * step;
            ticks = min(max(ticks, limits(1)), limits(2)) + 0;   % no tick 1e-14 outside; -0 becomes 0
        end

        function ok = reportError(app, err, context)
            app.LastError = err.message;
            app.setStatus(['Error (' context '): ' err.message]);
            uialert(app.UIFigure, err.message, [context ' error']);
            ok = false;
        end

        function setStatus(app, text)
            app.Controls.StatusLabel.Text = text;
        end

        function h = symbolSize(app)
            x = app.Model.nodes.x;
            h = 0.04 * (x(end) - x(1));
        end

        function drawModelTab(app)
            c = app.Controls;
            prims = bridgeDrawing(app.Model, app.drawingOptions(struct('ShowNumbers', c.NumbersCheckBox.Value)));
            cla(c.ModelAxes);
            renderDrawing(c.ModelAxes, prims, app.Units);
            title(c.ModelAxes, 'Bridge model: supports and permanent loads');
        end

        function drawPositionView(app)
            c = app.Controls;
            th = app.Theme;
            res = app.PositionResult;
            d = responseDiagramData(res);
            h = app.symbolSize();
            magnification = c.MagnificationField.Value;
            vMax = max(abs(d.v));
            if magnification <= 0
                magnification = 1;
                if vMax > 0
                    magnification = 0.8 * h / vMax;
                end
            end
            U = app.Units;
            opts = app.drawingOptions(struct('ShowNumbers', c.NumbersCheckBox.Value, 'Axles', res.axles, ...
                'Direction', app.Direction, 'Deformed', struct('x', d.x, 'y', d.v * magnification), ...
                'DeformedLabel', sprintf('deformed shape (dashed) x %.4g', magnification)));
            cla(c.BeamAxes);
            renderDrawing(c.BeamAxes, bridgeDrawing(app.Model, opts), U);
            title(c.BeamAxes, sprintf('%s at x_v = %.3f %s (quasi-static)', app.Vehicle.name, ...
                app.Position / U.length.toSI, U.length.unit));
            x = d.x / U.length.toSI;
            xl = sprintf('x [%s]', U.length.unit);
            plotDiagram(c.MomentAxes, x, d.M / U.moment.toSI, th.moment, sprintf('M [%s]', U.moment.unit), ...
                'Bending moment (+ sagging)', xl);
            plotDiagram(c.ShearAxes, x, d.V / U.force.toSI, th.shear, sprintf('V [%s]', U.force.unit), 'Shear force', xl);
            plotDiagram(c.DeflectionAxes, x, d.v / U.deflection.toSI, th.deflection, sprintf('v [%s]', U.deflection.unit), ...
                'Vertical deflection (+ up)', xl);
        end

        function drawEnvelopes(app)
            c = app.Controls;
            th = app.Theme;
            ml = app.MovingLoad;
            U = app.Units;
            e = ml.envelope;
            x = ml.stations / U.length.toSI;
            cr = ml.critical;
            xc = [cr.x] / U.length.toSI;
            m = U.moment.toSI;
            f = U.force.toSI;
            v = U.deflection.toSI;
            xl = sprintf('x [%s]', U.length.unit);
            plotEnvelope(c.EnvMomentAxes, x, e.Mmax / m, e.Mmin / m, th.envelopeMax, th.envelopeMin, ...
                sprintf('M [%s]', U.moment.unit), 'Moment envelope (+ sagging)', xc(1:2), [cr(1:2).value] / m, xl);
            plotEnvelope(c.EnvShearAxes, x, e.Vmax / f, e.Vmin / f, th.envelopeMax, th.envelopeMin, ...
                sprintf('V [%s]', U.force.unit), 'Shear envelope', xc(3:4), [cr(3:4).value] / f, xl);
            plotEnvelope(c.EnvDeflectionAxes, x, e.vmax / v, e.vmin / v, th.envelopeMax, th.envelopeMin, ...
                sprintf('v [%s]', U.deflection.unit), 'Deflection envelope (+ up)', xc(5:6), [cr(5:6).value] / v, xl);
            [data, columns] = criticalTableData(ml, U);
            c.CriticalTable.Data = data;
            c.CriticalTable.ColumnName = columns;
            [data, columns] = reactionEnvelopeTableData(ml, app.Model.nodes.x, U);
            c.EnvReactionsTable.Data = data;
            c.EnvReactionsTable.ColumnName = columns;
            veh = ml.vehicle;
            c.EnvelopeInfo.HTMLSource = infoPanelHtml('envelope', { ...
                sprintf('%s: axle loads %s %s, spacings %s %s (front axle = x_v).', veh.name, ...
                    numberListText(veh.axleLoads.' / f), U.force.unit, numberListText(veh.axleSpacings.' / U.length.toSI), ...
                    U.length.unit); ...
                sprintf('%d positions at step %.4g %s plus %d refined positions; travel %s.', ...
                    ml.nCoarse, ml.step / U.length.toSI, U.length.unit, ml.nRefined, app.DirectionItems{(3 - ml.direction) / 2}); ...
                'Permanent model loads are included at every position. Quasi-static: no impact or dynamic effects.'});
        end

        function clearDamageResults(app)
            c = app.Controls;
            app.DamageComparison = [];
            app.DamageSensitivity = [];
            c.DamageTable.Data = cell(0, 5);
            c.SensitivityTable.Data = cell(0, 6);
            c.SensitivityTable.ColumnName = {};         % headers (with units) come with the results
            c.DamageFindings.HTMLSource = infoPanelHtml('message', ...
                {'Press "Compare healthy vs damaged" to fill the plots, the table and these findings.'});
            names = {'DamageMomentAxes', 'DamageShearAxes', 'DamageDeflectionAxes', 'SensitivityAxes'};
            hints = {'Moment envelope', 'Shear envelope', 'Deflection envelope', 'Sensitivity'};
            for k = 1:numel(names)
                cla(c.(names{k}));
                legend(c.(names{k}), 'off');            % cla keeps an existing legend box
                title(c.(names{k}), hints{k});
            end
        end

        function drawDamageModel(app)
            c = app.Controls;
            factor = [];
            if ~isempty(app.DamagedModel)
                factor = app.DamagedModel.elements.stiffnessFactor;
            end
            prims = bridgeDrawing(app.Model, app.drawingOptions(struct('StiffnessFactor', factor, ...
                'ShowNumbers', c.NumbersCheckBox.Value)));
            cla(c.DamageAxes);
            renderDrawing(c.DamageAxes, prims, app.Units);
            title(c.DamageAxes, 'Damaged region (prescribed EI loss) on the healthy model');
        end

        function clearEnvelopes(app)
            c = app.Controls;
            c.CriticalTable.Data = cell(0, 7);
            c.CriticalTable.ColumnName = {};            % headers (with units) come with the results
            c.EnvReactionsTable.Data = cell(0, 7);
            c.EnvReactionsTable.ColumnName = {};
            c.EnvelopeInfo.HTMLSource = infoPanelHtml('message', ...
                {'Press "Run moving-load analysis" to compute envelopes for the current model and vehicle.'});
            for ax = {c.EnvMomentAxes, c.EnvShearAxes, c.EnvDeflectionAxes}
                cla(ax{1});
                legend(ax{1}, 'off');                   % cla keeps an existing legend box
            end
        end

        function resetIdentification(app)
            % New model: default sensors and truck positions, a hidden region on nodes, no readings.
            c = app.Controls;
            [sensors, positions] = identificationDefaults(app.Model, app.Vehicle, app.Direction);
            app.setPointTable(c.SensorsTable, sensors / app.Units.length.toSI, 'S');
            app.setPointTable(c.PositionsTable, positions / app.Units.length.toSI, 'P');
            k = max(1, round((numel(app.NodeX) - 1) / 3));         % hidden region: one element at about L/3
            c.HiddenFromDropDown.Value = c.HiddenFromDropDown.Items{k};
            c.HiddenToDropDown.Value = c.HiddenToDropDown.Items{k + 1};
            app.clearIdentificationReadings();
        end

        function clearIdentificationReadings(app)
            c = app.Controls;
            app.IdentTruth = [];
            app.ReadingsSetup = [];
            c.ReadingsTable.Data = zeros(0, 0);
            c.ReadingsTable.ColumnName = {};
            c.ReadingsTable.RowName = {};
            app.clearIdentificationResults();
            c.IdentInfo.HTMLSource = infoPanelHtml('message', ...
                {'1. Check the sensors and truck positions (vehicle and direction come from the Vehicle tab).'; ...
                '2. Generate synthetic readings of a hidden case, or press "New empty table" and type measured deflections.'; ...
                '3. State the reading noise and press "Run identification".'});
        end

        function clearIdentificationResults(app)
            c = app.Controls;
            app.IdentResult = [];
            c.CandidateTable.Data = cell(0, 7);
            c.CandidateTable.ColumnName = {};           % headers (with units) come with the results
            c.IdentResultText.HTMLSource = infoPanelHtml('message', {'Press "Run identification": the result appears here.'});
            cla(c.FitAxes);
            legend(c.FitAxes, 'off');
            cla(c.ReadingsAxes);
            legend(c.ReadingsAxes, 'off');
            title(c.ReadingsAxes, 'Readings and fits');
            app.drawIdentification();
        end

        function [sensors, positions] = identificationSetup(app)
            c = app.Controls;
            if isempty(app.Model) || isempty(app.Vehicle)
                error('BridgeFE:invalidInput', 'Apply a model and a vehicle first.');
            end
            U = app.Units;
            sensors = coordinatesFromTable(c.SensorsTable.Data, 'Sensor', 'x', U);
            positions = coordinatesFromTable(c.PositionsTable.Data, 'Truck position', 'x_v', U);
            x = app.Model.nodes.x;
            tol = 1e-5 * (x(end) - x(1));          % covers an end coordinate typed as shown (6 digits)
            off = find(sensors < x(1) - tol | sensors > x(end) + tol, 1);
            if ~isempty(off)
                error('BridgeFE:offBeam', 'Sensor %d: x = %g %s is not on the beam (%g to %g %s).', off, ...
                    sensors(off) / U.length.toSI, U.length.unit, x(1) / U.length.toSI, x(end) / U.length.toSI, U.length.unit);
            end
            sensors = min(max(sensors, x(1)), x(end));
        end

        function setReadingsTable(app, uObs, sensors, positions)
            c = app.Controls;
            U = app.Units;
            app.ReadingsSetup = struct('sensors', sensors, 'positions', positions);
            c.ReadingsTable.Data = uObs * (1 / U.deflection.toSI);    % display unit (mm or in); the inverse of readingsFromTable
            c.ReadingsTable.ColumnName = arrayfun(@(v) sprintf('x_v = %g %s', v / U.length.toSI, U.length.unit), ...
                positions, 'UniformOutput', false);
            c.ReadingsTable.RowName = arrayfun(@(k) sprintf('S%d (x = %g %s)', k, sensors(k) / U.length.toSI, ...
                U.length.unit), 1:numel(sensors), 'UniformOutput', false);
            c.ReadingsTable.ColumnEditable = true(1, numel(positions));
            app.clearIdentificationResults();
            uHealthy = predictSensorDeflections(app.Model, app.Vehicle, positions, sensors, app.Direction);
            plotReadings(c.ReadingsAxes, positions, sensors, uObs, uHealthy, [], app.Theme, U);
            c.IdentResultTabs.SelectedTab = c.IdentReadingsTab;
        end

        function onReadingsEdited(app)
            % Typed readings replace the synthetic case: its hidden truth no longer describes them.
            c = app.Controls;
            app.IdentTruth = [];
            app.clearIdentificationResults();
            c.IdentInfo.HTMLSource = infoPanelHtml('message', ...
                {'Readings edited: they are treated as measured data, so the synthetic hidden case is no longer compared.'; ...
                'Press "Run identification".'});
            try
                s = app.ReadingsSetup;
                uObs = readingsFromTable(c.ReadingsTable.Data, numel(s.sensors), numel(s.positions), app.Units);
                uHealthy = predictSensorDeflections(app.Model, app.Vehicle, s.positions, s.sensors, app.Direction);
                plotReadings(c.ReadingsAxes, s.positions, s.sensors, uObs, uHealthy, [], app.Theme, app.Units);
            catch err
                app.setStatus(['Readings edited: ' err.message]);
                return
            end
            app.setStatus('Readings edited: press "Run identification" again.');
        end

        function drawIdentification(app)
            c = app.Controls;
            if isempty(app.Model)
                return
            end
            opts = app.drawingOptions(struct());       % no node numbers: labels need the room
            try
                opts.Sensors = app.identificationSetup();
            catch
                opts.Sensors = [];                      % invalid sensor text: draw the beam only
            end
            r = app.IdentResult;
            if ~isempty(r)
                opts.Regions = r.uncertaintyRegions;
                if r.damageDetected
                    opts.BestRegion = r.best.x;
                    opts.BestLabel = sprintf('best fit: d = %s %%', formatNumber(100 * r.best.d, 1));
                end
                if ~isempty(app.IdentTruth) && app.IdentTruth.d > 0
                    opts.TrueRegion = app.IdentTruth.x;
                end
            end
            cla(c.IdentAxes);
            renderDrawing(c.IdentAxes, bridgeDrawing(app.Model, opts), app.Units);
            title(c.IdentAxes, 'Sensors, region of uncertainty and best fit');
        end

        function in = modelTableInputs(app)
            % The Bridge model tab's tables and fields as BUILDMODELFROMTABLES input (display units).
            c = app.Controls;
            spans = c.SpansTable.Data;
            in.spanLengths = spans(:, 1)';
            in.elementsPerSpan = spans(:, 2)';
            in.supportTypes = c.SupportsTable.Data(:, 3)';
            in.materialType = lower(c.MaterialDropDown.Value);
            in.E = c.EField.Value;
            in.I = c.IField.Value;
            in.udlDown = c.UDLField.Value;
            in.materialName = c.MaterialNameField.Value;
            in.materialBasis = c.BasisField.Value;
        end

        function v = tableNumbers(~, data, k)
            % Column K of table data as a row of numbers (NaN where a cell is empty, text or not finite),
            % read as BUILDMODELFROMTABLES and VEHICLEFROMTABLE read it.
            if isnumeric(data)
                v = double(data(:, k))';
                v(~isfinite(v)) = NaN;
                return
            end
            v = NaN(1, size(data, 1));
            for r = 1:size(data, 1)
                x = data{r, k};
                if isnumeric(x) && isscalar(x) && isreal(x) && isfinite(x)
                    v(r) = double(x);
                end
            end
        end

        function refreshSupportsTable(app)
            % One row per span end, lettered A, B, ... with its x; the chosen types are kept, new ends are rollers.
            c = app.Controls;
            U = app.Units;
            spans = c.SpansTable.Data;
            lengths = app.tableNumbers(spans, 1);
            n = numel(lengths) + 1;
            letters = supportLetters(n);
            xs = [0, cumsum(lengths)];
            old = c.SupportsTable.Data;
            data = cell(n, 3);
            for k = 1:n
                type = 'Roller';
                if k == 1
                    type = 'Pin';
                end
                if k <= size(old, 1)
                    type = old{k, 3};
                end
                data(k, :) = {letters{k}, xs(k), type};
            end
            c.SupportsTable.Data = data;
            c.SupportsTable.ColumnName = {'Support', sprintf('x [%s]', U.length.unit), 'Type'};
            c.SpansTable.RowName = arrayfun(@(k) sprintf('Span %d', k), 1:size(spans, 1), 'UniformOutput', false);
        end

        function previewModel(app, quiet)
            % Draw the model typed in the tables before it is applied (no analysis is reset). QUIET (redraws:
            % node numbers, deformation scale) leaves the status line alone.
            if nargin < 2
                quiet = false;
            end
            c = app.Controls;
            try
                [model, info] = buildModelFromTables(app.modelTableInputs(), app.Units);
            catch err
                if ~quiet                                % a redraw keeps the status (e.g. a run's summary)
                    app.setStatus(['Model input: ' err.message]);
                end
                return
            end
            opts = app.drawingOptions(struct('ShowNumbers', c.NumbersCheckBox.Value), info);
            opts.SymbolSize = 0.04 * (model.nodes.x(end) - model.nodes.x(1));
            cla(c.ModelAxes);
            renderDrawing(c.ModelAxes, bridgeDrawing(model, opts), app.Units);
            title(c.ModelAxes, 'Preview: press "Apply model" to use this model');
            c.SummaryArea.HTMLSource = infoPanelHtml('model', info.summary);
            app.Previewing = true;
            if ~quiet
                app.setStatus('Model edited: press "Apply model" to analyse it.');
            end
        end

        function refreshRegionChoices(app)
            % Node drop-downs (Damage and Identification tabs) and the support drop-down for a new model or units.
            c = app.Controls;
            U = app.Units;
            [labels, xSI] = nodeChoices(app.Model, U);
            app.NodeX = xSI;
            n = numel(xSI);
            pick = @(frac) labels{min(n, max(1, round(frac * (n - 1)) + 1))};
            dropDowns = {c.DamageFromDropDown, c.DamageToDropDown, c.HiddenFromDropDown, c.HiddenToDropDown};
            values = {pick(0.375), pick(0.625), labels{1}, labels{min(2, n)}};
            for k = 1:4
                dropDowns{k}.Items = labels;
                dropDowns{k}.Value = values{k};
            end
            info = app.ModelInfo;
            supported = find(~strcmpi(info.supportTypes, 'Free'));
            supported = supported(:)';
            items = arrayfun(@(k) sprintf('%s (x = %g %s)', info.supportLetters{k}, info.supportX(k) / U.length.toSI, ...
                U.length.unit), supported, 'UniformOutput', false);
            c.SupportDropDown.Items = items;
            c.SupportDropDown.Value = items{1};
            app.SupportNodes = arrayfun(@(k) findNodeAtX(app.Model, info.supportX(k)), supported);
        end

        function x = selectedNodeX(app, dropDown)
            x = app.NodeX(strcmp(dropDown.Items, dropDown.Value));
        end

        function node = selectedSupportNode(app)
            c = app.Controls;
            node = app.SupportNodes(strcmp(c.SupportDropDown.Items, c.SupportDropDown.Value));
        end

        function opts = drawingOptions(app, opts, info)
            % Common drawing options: symbol size, theme, display units and the support letters at the span ends.
            if nargin < 3
                info = app.ModelInfo;
                opts.SymbolSize = app.symbolSize();
            end
            opts.Theme = app.Theme;
            opts.Units = app.Units;
            ends.x = info.supportX;
            ends.text = info.supportLetters;
            opts.EndLabels = ends;
        end

        function onUnitsChanged(app)
            % Unit-system drop-down: convert every typed input to the new units, relabel, rebuild.
            c = app.Controls;
            systems = {'SI', 'US'};
            new = unitSystem(systems{strcmp(app.unitLabels(), c.UnitsDropDown.Value)});
            old = app.Units;
            if strcmp(old.name, new.name)
                return
            end
            % The switch re-applies the model and the vehicle. While one of their inputs is invalid it
            % is refused, so no part of the app is left in the old units under new labels.
            try
                app.checkModelAndVehicleInputs(old);
            catch err
                c.UnitsDropDown.Value = old.label;
                msg = sprintf('%s The units stay %s: correct this input, then switch again.', err.message, old.name);
                app.LastError = msg;
                app.setStatus(['Error (Unit switch): ' msg]);
                uialert(app.UIFigure, msg, 'Unit switch error');
                return
            end
            % Converted inputs keep 12 significant digits (12 m -> 39.3700787402 ft). Switching back
            % restores every input not edited since the last switch exactly, so SI -> US -> SI gives
            % the same model. Rows added since the last switch are converted; the rows the table
            % had then are compared one by one.
            kinds = struct('spans', 'length', 'loads', 'force', 'spacings', 'length', 'E', 'modulus', ...
                'I', 'inertia', 'udl', 'distributed', 'step', 'length', 'sensitivityStep', 'length', ...
                'noiseAbs', 'deflection', 'sensors', 'length', 'positions', 'length');
            names = fieldnames(kinds);
            before = app.unitInputs();
            after = before;
            mem = app.UnitMemory;
            useMemory = ~isempty(mem) && strcmp(mem.units, old.name);
            for k = 1:numel(names)
                n = names{k};
                factor = old.(kinds.(n)).toSI / new.(kinds.(n)).toSI;
                v = before.(n);
                w = v;
                for j = 1:numel(v)
                    w(j) = str2double(sprintf('%.12g', v(j) * factor));
                end
                if useMemory
                    shown = mem.shown.(n);
                    m = min(numel(v), numel(shown));
                    same = find(v(1:m) == shown(1:m));  % not edited since the last switch
                    w(same) = mem.previous.(n)(same);
                end
                after.(n) = w;
            end
            applied = app.appliedSignature();
            app.setUnitInputs(after);
            app.UnitMemory = struct('units', new.name, 'shown', after, 'previous', before);
            app.Units = new;
            app.updateUnitLabels();
            app.refreshSupportsTable();
            okModel = app.applyModelInputs();
            okVehicle = app.applyVehicleInputs();
            kept = okModel && okVehicle && app.sameSignature(applied, app.appliedSignature());
            if kept
                % A pure unit switch keeps the user's sensors and truck positions (converted); Apply model reset them.
                app.setPointTable(c.SensorsTable, after.sensors, 'S');
                app.setPointTable(c.PositionsTable, after.positions, 'P');
                app.drawIdentification();
            end
            if kept
                app.setStatus(sprintf('Units: %s. Every input was converted; press the run buttons for results.', new.label));
            elseif okModel && okVehicle
                app.setStatus(sprintf(['Units: %s. Every input was converted. Pending model or vehicle edits were ' ...
                    'applied with the switch, so the sensors and truck positions are the defaults.'], new.label));
            end
        end

        function sig = appliedSignature(app)
            % The applied model and vehicle in SI: a switch that changes any of them applied pending edits, as
            % "Apply model" or "Apply vehicle" would (supports decide where a sensor reads zero).
            m = app.Model;
            sig = struct('x', m.nodes.x(:)', 'supportNodes', m.supports.node(:)', ...
                'restraint', double(m.supports.restraint), 'EI', m.elements.EI(:)', 'udl', m.loads.elementUDL(:)', ...
                'loads', app.Vehicle.axleLoads(:)', 'spacings', app.Vehicle.axleSpacings(:)', 'direction', app.Direction);
        end

        function same = sameSignature(~, a, b)
            % Equal up to the 12-digit unit conversion.
            near = @(p, q) isequal(size(p), size(q)) && all(abs(p(:) - q(:)) <= 1e-9 * max(abs(q(:)), 1));
            same = near(a.x, b.x) && isequal(a.supportNodes, b.supportNodes) && isequal(a.restraint, b.restraint) ...
                && near(a.EI, b.EI) && near(a.udl, b.udl) && near(a.loads, b.loads) && near(a.spacings, b.spacings) ...
                && a.direction == b.direction;
        end

        function checkModelAndVehicleInputs(app, U)
            % Throw the first error that "Apply model" or "Apply vehicle" would report (inputs in units U).
            state = warning('off', 'BridgeFE:unusualModulus');   % reported by Apply model itself
            restore = onCleanup(@() warning(state)); %#ok<NASGU>
            buildModelFromTables(app.modelTableInputs(), U);
            app.vehicleInput(U);
        end

        function vehicle = vehicleInput(app, U)
            % The Vehicle tab's axle table and position step (in units U) as an SI engine vehicle.
            c = app.Controls;
            data = c.AxlesTable.Data;
            vehicle = vehicleFromTable(data(:, 1)', data(1:end-1, 2)', c.VehicleNameField.Value, U);
            assertPositiveFiniteScalar(c.StepField.Value, sprintf('Position step [%s]', U.length.unit));
        end

        function s = unitInputs(app)
            % The inputs that carry units, as rows of numbers in the current display units.
            c = app.Controls;
            axles = c.AxlesTable.Data;
            s.spans = app.tableNumbers(c.SpansTable.Data, 1);
            s.loads = app.tableNumbers(axles, 1);
            s.spacings = app.tableNumbers(axles(1:end-1, :), 2);
            s.E = c.EField.Value;
            s.I = c.IField.Value;
            s.udl = c.UDLField.Value;
            s.step = c.StepField.Value;
            s.sensitivityStep = c.SensitivityStepField.Value;
            s.noiseAbs = c.SearchNoiseAbsField.Value;
            s.sensors = app.tableNumbers(c.SensorsTable.Data, 1);
            s.positions = app.tableNumbers(c.PositionsTable.Data, 1);
        end

        function setUnitInputs(app, s)
            c = app.Controls;
            spans = c.SpansTable.Data;
            for r = 1:size(spans, 1)
                spans{r, 1} = s.spans(r);
            end
            c.SpansTable.Data = spans;
            app.setAxleTable(s.loads, s.spacings);
            c.EField.Value = s.E;
            c.IField.Value = s.I;
            c.UDLField.Value = s.udl;
            c.StepField.Value = s.step;
            c.SensitivityStepField.Value = s.sensitivityStep;
            c.SearchNoiseAbsField.Value = s.noiseAbs;
            app.setPointTable(c.SensorsTable, s.sensors, 'S');
            app.setPointTable(c.PositionsTable, s.positions, 'P');
        end

        function updateUnitLabels(app)
            c = app.Controls;
            U = app.Units;
            c.SpansTable.ColumnName = {sprintf('Length [%s]', U.length.unit), 'Elements'};
            c.ELabel.Text = sprintf('E [%s]', U.modulus.unit);
            app.updateInertiaLabel();
            c.UDLLabel.Text = sprintf('Uniform load, down [%s]', U.distributed.unit);
            c.AxlesTable.ColumnName = {sprintf('Load [%s]', U.force.unit), sprintf('Spacing to next axle [%s]', U.length.unit)};
            c.StepLabel.Text = sprintf('Position step [%s]', U.length.unit);
            c.SensitivityStepLabel.Text = sprintf('Sweep position step [%s]', U.length.unit);
            c.SensorsTable.ColumnName = {sprintf('x [%s]', U.length.unit)};
            c.PositionsTable.ColumnName = {sprintf('x_v [%s]', U.length.unit)};
            c.SearchNoiseAbsLabel.Text = sprintf('Reading noise [%s]', U.deflection.unit);
            c.SearchNoiseField.Tooltip = app.noiseTooltip();
            c.IdentReadingsTab.Title = sprintf('Readings [%s]', U.deflection.unit);
            [~, items] = candidateRegionLength([], U);
            c.RegionSizeDropDown.Items = items;
            c.RegionSizeDropDown.Value = items{1};
            app.updateAxleTotal();
        end

        function onPresetChanged(app)
            % Vehicle preset drop-down: fill the axle table (Custom keeps the table).
            c = app.Controls;
            presets = vehiclePresets(app.Units);
            p = presets(strcmp({presets.name}, c.PresetDropDown.Value));
            c.PresetNote.Text = p.note;
            if isempty(p.loads)
                return
            end
            app.setAxleTable(p.loads, p.spacings);
            c.VehicleNameField.Value = p.name;
            app.setStatus(app.vehicleEditedText());
        end

        function setAxleTable(app, loads, spacings)
            c = app.Controls;
            n = numel(loads);
            data = cell(n, 2);
            for k = 1:n
                data{k, 1} = loads(k);
                if k < n
                    data{k, 2} = spacings(k);
                else
                    data{k, 2} = [];                        % no axle behind the last one
                end
            end
            c.AxlesTable.Data = data;
            c.AxlesTable.RowName = [{'Axle 1 (front)'}, arrayfun(@(k) sprintf('Axle %d', k), 2:n, 'UniformOutput', false)];
            app.updateAxleTotal();
        end

        function updateAxleTotal(app)
            c = app.Controls;
            U = app.Units;
            data = c.AxlesTable.Data;
            loads = app.tableNumbers(data, 1);
            spacings = app.tableNumbers(data(1:end-1, :), 2);
            c.AxleTotalLabel.Text = sprintf('Total %g %s, length %g %s; the front axle is the vehicle position x_v.', ...
                sum(loads), U.force.unit, sum(spacings), U.length.unit);
        end

        function labels = unitLabels(~)
            % Unit-system drop-down items, in the order 'SI', 'US'.
            si = unitSystem('SI');
            us = unitSystem('US');
            labels = {si.label, us.label};
        end

        function onTabChanged(app, event)
            if strcmp(event.NewValue.Title, 'Matrices')
                app.showMatrices();
            end
        end

        function createComponents(app)
            th = app.Theme;
            fig = uifigure('Name', 'CE 7405 Bridge Analysis (2D equivalent beam)', ...
                'Position', [60 60 1380 860], 'Color', th.background);
            fig.CloseRequestFcn = @(~, ~) delete(app);
            app.UIFigure = fig;
            main = uigridlayout(fig, [2 1]);
            main.RowHeight = {'1x', 26};
            main.ColumnWidth = {'1x'};
            main.BackgroundColor = th.background;
            tabs = uitabgroup(main);
            tabs.Layout.Row = 1;
            tabs.Layout.Column = 1;
            tabs.SelectionChangedFcn = @(~, event) app.onTabChanged(event);
            c.StatusLabel = uilabel(main, 'Text', 'Ready.', 'FontColor', th.text, 'BackgroundColor', th.panel);
            c.StatusLabel.Layout.Row = 2;
            c.StatusLabel.Layout.Column = 1;

            % ---- Tab 1: Bridge model
            U = app.Units;
            [supportLabels] = supportTypeList();
            t1 = uitab(tabs, 'Title', 'Bridge model', 'BackgroundColor', th.background);
            g1 = uigridlayout(t1, [1 2]);
            g1.ColumnWidth = {460, '1x'};   % every tab: room for the reactions table and long names
            g1.BackgroundColor = th.background;
            p1 = uipanel(g1, 'Title', 'Model input', 'BackgroundColor', th.panel, 'FontWeight', 'bold', ...
                'ForegroundColor', th.sageDark);
            p1.Layout.Row = 1;
            p1.Layout.Column = 1;
            f1 = uigridlayout(p1, [15 2]);
            f1.RowHeight = {26, 18, 110, 26, 18, 116, 26, 26, 26, 26, 26, 26, 22, 30, '1x'};
            f1.RowSpacing = 6;
            f1.Scrollable = 'on';                       % small windows: scroll rather than cut rows
            f1.ColumnWidth = {170, '1x'};
            f1.BackgroundColor = th.panel;
            c.UnitsDropDown = app.labeled(f1, 1, 'Unit system', uidropdown(f1, 'Items', ...
                app.unitLabels(), 'Value', U.label, ...
                'Tooltip', 'Converts every input and result', 'ValueChangedFcn', @(~, ~) app.onUnitsChanged()));
            lbl = uilabel(f1, 'Text', 'Spans, left to right', 'FontWeight', 'bold', 'FontColor', th.sageDark);
            lbl.Layout.Row = 2;
            lbl.Layout.Column = [1 2];
            c.SpansTable = uitable(f1, 'Data', {20, 16}, 'ColumnName', {sprintf('Length [%s]', U.length.unit), 'Elements'}, ...
                'RowName', {'Span 1'}, 'ColumnEditable', [true true], 'ColumnFormat', {'numeric', 'numeric'}, ...
                'ColumnWidth', {130, 90}, 'CellEditCallback', @(~, ~) app.onSpansEdited());
            c.SpansTable.Layout.Row = 3;
            c.SpansTable.Layout.Column = [1 2];
            b = uibutton(f1, 'push', 'Text', '+ Add span', 'FontColor', th.sage, 'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~, ~) app.addSpan());
            b.Layout.Row = 4;
            b.Layout.Column = 1;
            b = uibutton(f1, 'push', 'Text', '- Remove last span', 'ButtonPushedFcn', @(~, ~) app.removeSpan());
            b.Layout.Row = 4;
            b.Layout.Column = 2;
            lbl = uilabel(f1, 'Text', 'Supports at the span ends', 'FontWeight', 'bold', 'FontColor', th.sageDark);
            lbl.Layout.Row = 5;
            lbl.Layout.Column = [1 2];
            c.SupportsTable = uitable(f1, 'Data', {'A', 0, 'Pin'; 'B', 20, 'Roller'}, 'ColumnName', ...
                {'Support', sprintf('x [%s]', U.length.unit), 'Type'}, 'RowName', {}, 'ColumnEditable', [false false true], ...
                'ColumnFormat', {'char', 'numeric', supportLabels}, 'ColumnWidth', {70, 100, 110}, ...
                'CellEditCallback', @(~, ~) app.previewModel());
            c.SupportsTable.Layout.Row = 6;
            c.SupportsTable.Layout.Column = [1 2];
            c.MaterialDropDown = app.labeled(f1, 7, 'Material (all spans)', uidropdown(f1, 'Items', {'Steel', 'RCC'}, ...
                'Value', 'Steel', 'ValueChangedFcn', @(~, ~) app.onMaterialChanged()));
            [c.EField, c.ELabel] = app.labeled(f1, 8, sprintf('E [%s]', U.modulus.unit), uieditfield(f1, 'numeric', ...
                'Value', 200, 'Limits', [0 Inf], 'LowerLimitInclusive', 'off', 'ValueDisplayFormat', '%.6g', ...
                'ValueChangedFcn', @(~, ~) app.previewModel()));
            [c.IField, c.ILabel] = app.labeled(f1, 9, sprintf('Is [%s]', U.inertia.unit), uieditfield(f1, 'numeric', ...
                'Value', 0.01, 'Limits', [0 Inf], 'LowerLimitInclusive', 'off', 'ValueDisplayFormat', '%.6g', ...
                'ValueChangedFcn', @(~, ~) app.previewModel()));
            c.MaterialNameField = app.labeled(f1, 10, 'Material name', uieditfield(f1, 'text', 'Value', '', ...
                'Tooltip', 'A label for your records, shown in the summary; it does not change any result', ...
                'ValueChangedFcn', @(~, ~) app.previewModel()));
            c.BasisField = app.labeled(f1, 11, 'Basis of E and I', uieditfield(f1, 'text', 'Value', '', ...
                'Tooltip', 'Where E and I (or Ieff) come from; shown in the summary, no effect on results', ...
                'ValueChangedFcn', @(~, ~) app.previewModel()));
            [c.UDLField, c.UDLLabel] = app.labeled(f1, 12, sprintf('Uniform load, down [%s]', U.distributed.unit), ...
                uieditfield(f1, 'numeric', 'Value', 0, 'Limits', [0 Inf], 'ValueDisplayFormat', '%.6g', ...
                'ValueChangedFcn', @(~, ~) app.previewModel()));
            c.NumbersCheckBox = uicheckbox(f1, 'Text', 'Show node and element numbers', 'Value', false, ...
                'ValueChangedFcn', @(~, ~) app.redrawAll());
            c.NumbersCheckBox.Layout.Row = 13;
            c.NumbersCheckBox.Layout.Column = [1 2];
            b = uibutton(f1, 'push', 'Text', 'Apply model', 'BackgroundColor', th.sage, ...
                'FontColor', th.buttonText, 'FontWeight', 'bold', 'ButtonPushedFcn', @(~, ~) app.applyModelInputs());
            b.Layout.Row = 14;
            b.Layout.Column = [1 2];
            r1 = uigridlayout(g1, [2 1]);
            r1.Layout.Row = 1;
            r1.Layout.Column = 2;
            r1.RowHeight = {'1x', 240};                 % model summary and the modelling notes (two columns)
            r1.BackgroundColor = th.background;
            c.ModelAxes = uiaxes(r1);
            c.ModelAxes.Layout.Row = 1;
            c.ModelAxes.Layout.Column = 1;
            c.SummaryArea = uihtml(r1, 'HTMLSource', infoPanelHtml('message', {'Press "Apply model".'}));
            c.SummaryArea.Layout.Row = 2;
            c.SummaryArea.Layout.Column = 1;

            % ---- Tab 2: Vehicle and moving load
            presets = vehiclePresets(U);
            t2 = uitab(tabs, 'Title', 'Vehicle & moving load', 'BackgroundColor', th.background);
            g2 = uigridlayout(t2, [1 2]);
            g2.ColumnWidth = {460, '1x'};   % every tab: room for the reactions table and long names
            g2.BackgroundColor = th.background;
            p2 = uipanel(g2, 'Title', 'Vehicle (quasi-static)', 'BackgroundColor', th.panel, 'FontWeight', 'bold', ...
                'ForegroundColor', th.sageDark);
            p2.Layout.Row = 1;
            p2.Layout.Column = 1;
            f2 = uigridlayout(p2, [14 2]);
            f2.RowHeight = {18, 26, 44, 26, 18, 116, 26, 20, 26, 26, 26, 30, 20, '1x'};
            f2.RowSpacing = 6;
            f2.ColumnWidth = {170, '1x'};
            f2.BackgroundColor = th.panel;
            f2.Scrollable = 'on';
            lbl = uilabel(f2, 'Text', 'Vehicle preset', 'FontWeight', 'bold', 'FontColor', th.sageDark);
            lbl.Layout.Row = 1;
            lbl.Layout.Column = [1 2];
            c.PresetDropDown = uidropdown(f2, 'Items', {presets.name}, 'Value', presets(1).name, ...
                'ValueChangedFcn', @(~, ~) app.onPresetChanged());   % full width: the preset names are long
            c.PresetDropDown.Layout.Row = 2;
            c.PresetDropDown.Layout.Column = [1 2];
            c.PresetNote = uilabel(f2, 'Text', presets(1).note, 'WordWrap', 'on', 'FontSize', 11, 'FontColor', th.text);
            c.PresetNote.Layout.Row = 3;
            c.PresetNote.Layout.Column = [1 2];
            edited = @(~, ~) app.setStatus(app.vehicleEditedText());   % name, step and direction need Apply vehicle
            c.VehicleNameField = app.labeled(f2, 4, 'Vehicle name', uieditfield(f2, 'text', 'Value', presets(1).name, ...
                'ValueChangedFcn', edited));
            lbl = uilabel(f2, 'Text', 'Axles, front to rear', 'FontWeight', 'bold', 'FontColor', th.sageDark);
            lbl.Layout.Row = 5;
            lbl.Layout.Column = [1 2];
            c.AxlesTable = uitable(f2, 'Data', cell(0, 2), 'ColumnName', {sprintf('Load [%s]', U.force.unit), ...
                sprintf('Spacing to next axle [%s]', U.length.unit)}, 'ColumnEditable', [true true], ...
                'ColumnFormat', {'numeric', 'numeric'}, 'ColumnWidth', {110, 160}, ...
                'CellEditCallback', @(~, ~) app.onAxlesEdited());
            c.AxlesTable.Layout.Row = 6;
            c.AxlesTable.Layout.Column = [1 2];
            b = uibutton(f2, 'push', 'Text', '+ Add axle', 'FontColor', th.sage, 'FontWeight', 'bold', ...
                'ButtonPushedFcn', @(~, ~) app.addAxle());
            b.Layout.Row = 7;
            b.Layout.Column = 1;
            b = uibutton(f2, 'push', 'Text', '- Remove last axle', 'ButtonPushedFcn', @(~, ~) app.removeAxle());
            b.Layout.Row = 7;
            b.Layout.Column = 2;
            c.AxleTotalLabel = uilabel(f2, 'Text', '', 'FontSize', 11, 'FontColor', th.text);
            c.AxleTotalLabel.Layout.Row = 8;
            c.AxleTotalLabel.Layout.Column = [1 2];
            [c.StepField, c.StepLabel] = app.labeled(f2, 9, sprintf('Position step [%s]', U.length.unit), ...
                uieditfield(f2, 'numeric', 'Value', 0.1, 'Limits', [0 Inf], 'LowerLimitInclusive', 'off', ...
                'ValueDisplayFormat', '%.6g', 'ValueChangedFcn', edited));
            c.DirectionDropDown = app.labeled(f2, 10, 'Travel direction', uidropdown(f2, 'Items', app.DirectionItems, ...
                'Value', app.DirectionItems{1}, 'ValueChangedFcn', edited));
            c.MagnificationField = app.labeled(f2, 11, 'Deformation scale (0 = auto)', uieditfield(f2, 'numeric', ...
                'Value', 0, 'Limits', [0 Inf], 'ValueChangedFcn', @(~, ~) app.redrawAll()));
            b = uibutton(f2, 'push', 'Text', 'Apply vehicle', 'BackgroundColor', th.sage, ...
                'FontColor', th.buttonText, 'FontWeight', 'bold', 'ButtonPushedFcn', @(~, ~) app.applyVehicleInputs());
            b.Layout.Row = 12;
            b.Layout.Column = [1 2];
            c.ReactionsLabel = uilabel(f2, 'Text', 'Support reactions (forces + up, couples + CCW)', 'FontWeight', 'bold', ...
                'FontColor', th.sageDark);
            c.ReactionsLabel.Layout.Row = 13;
            c.ReactionsLabel.Layout.Column = [1 2];
            c.ReactionsTable = uitable(f2, 'Data', cell(0, 5), 'RowName', {}, 'ColumnWidth', 'fit');
            c.ReactionsTable.Layout.Row = 14;
            c.ReactionsTable.Layout.Column = [1 2];
            r2 = uigridlayout(g2, [5 1]);
            r2.Layout.Row = 1;
            r2.Layout.Column = 2;
            r2.RowHeight = {300, 44, '1x', '1x', '1x'};   % tall enough for the true-scale beam drawing
            r2.BackgroundColor = th.background;
            c.BeamAxes = uiaxes(r2);
            c.BeamAxes.Layout.Row = 1;
            c.BeamAxes.Layout.Column = 1;
            s2 = uigridlayout(r2, [1 5]);
            s2.Layout.Row = 2;
            s2.Layout.Column = 1;
            s2.ColumnWidth = {70, 70, '1x', 70, 330};
            s2.Padding = [0 0 0 0];
            s2.BackgroundColor = th.background;
            b = uibutton(s2, 'push', 'Text', 'Start', 'ButtonPushedFcn', @(~, ~) app.setVehiclePosition( ...
                app.startPosition()));
            b.Layout.Row = 1;
            b.Layout.Column = 1;
            b = uibutton(s2, 'push', 'Text', 'Back', 'ButtonPushedFcn', @(~, ~) app.stepVehicle(-1));
            b.Layout.Row = 1;
            b.Layout.Column = 2;
            c.PositionSlider = uislider(s2, 'Limits', [0 1], 'Value', 0, ...
                'ValueChangingFcn', @(~, event) app.setVehiclePosition(event.Value * app.Units.length.toSI), ...
                'ValueChangedFcn', @(src, ~) app.setVehiclePosition(src.Value * app.Units.length.toSI));
            c.PositionSlider.Layout.Row = 1;
            c.PositionSlider.Layout.Column = 3;
            b = uibutton(s2, 'push', 'Text', 'Forward', 'ButtonPushedFcn', @(~, ~) app.stepVehicle(1));
            b.Layout.Row = 1;
            b.Layout.Column = 4;
            c.PositionLabel = uilabel(s2, 'Text', 'x_v = -', 'FontColor', th.text, 'WordWrap', 'on');
            c.PositionLabel.Layout.Row = 1;
            c.PositionLabel.Layout.Column = 5;
            c.MomentAxes = uiaxes(r2);
            c.MomentAxes.Layout.Row = 3;
            c.MomentAxes.Layout.Column = 1;
            c.ShearAxes = uiaxes(r2);
            c.ShearAxes.Layout.Row = 4;
            c.ShearAxes.Layout.Column = 1;
            c.DeflectionAxes = uiaxes(r2);
            c.DeflectionAxes.Layout.Row = 5;
            c.DeflectionAxes.Layout.Column = 1;

            % ---- Tab 3: Envelopes
            t3 = uitab(tabs, 'Title', 'Envelopes', 'BackgroundColor', th.background);
            g3 = uigridlayout(t3, [3 2]);
            g3.ColumnWidth = {'1x', 660};
            g3.RowHeight = {'1x', '1x', '1x'};
            g3.BackgroundColor = th.background;
            c.EnvMomentAxes = uiaxes(g3);
            c.EnvMomentAxes.Layout.Row = 1;
            c.EnvMomentAxes.Layout.Column = 1;
            c.EnvShearAxes = uiaxes(g3);
            c.EnvShearAxes.Layout.Row = 2;
            c.EnvShearAxes.Layout.Column = 1;
            c.EnvDeflectionAxes = uiaxes(g3);
            c.EnvDeflectionAxes.Layout.Row = 3;
            c.EnvDeflectionAxes.Layout.Column = 1;
            r3 = uigridlayout(g3, [8 1]);
            r3.Layout.Row = [1 3];
            r3.Layout.Column = 2;
            r3.RowHeight = {34, 100, 22, '1x', 30, 22, '1x', 18};
            r3.BackgroundColor = th.background;
            b = uibutton(r3, 'push', 'Text', 'Run moving-load analysis', 'BackgroundColor', th.sage, ...
                'FontColor', th.buttonText, 'FontWeight', 'bold', 'ButtonPushedFcn', @(~, ~) app.runEnvelopes());
            b.Layout.Row = 1;
            b.Layout.Column = 1;
            c.EnvelopeInfo = uihtml(r3, 'HTMLSource', infoPanelHtml('message', {'Press "Run moving-load analysis".'}));
            c.EnvelopeInfo.Layout.Row = 2;
            c.EnvelopeInfo.Layout.Column = 1;
            lbl = uilabel(r3, 'Text', 'Critical vehicle positions (global extremes)', 'FontWeight', 'bold', ...
                'FontColor', th.sageDark);
            lbl.Layout.Row = 3;
            lbl.Layout.Column = 1;
            c.CriticalTable = uitable(r3, 'Data', cell(0, 7), 'ColumnName', {}, 'ColumnWidth', 'fit');
            c.CriticalTable.Layout.Row = 4;
            c.CriticalTable.Layout.Column = 1;
            c.CriticalLegend = app.legendLabel(r3, 5, 1, app.xLegendText('critical'));
            lbl = uilabel(r3, 'Text', 'Reaction envelopes', 'FontWeight', 'bold', 'FontColor', th.sageDark);
            lbl.Layout.Row = 6;
            lbl.Layout.Column = 1;
            c.EnvReactionsTable = uitable(r3, 'Data', cell(0, 7), 'ColumnName', {}, 'ColumnWidth', 'fit');
            c.EnvReactionsTable.Layout.Row = 7;
            c.EnvReactionsTable.Layout.Column = 1;
            c.ReactionLegend = app.legendLabel(r3, 8, 1, app.xLegendText('reaction'));

            % ---- Tab: Damage (Stage 2)
            t6 = uitab(tabs, 'Title', 'Damage (Stage 2)', 'BackgroundColor', th.background);
            g6 = uigridlayout(t6, [1 2]);
            g6.ColumnWidth = {460, '1x'};   % every tab: room for the reactions table and long names
            g6.BackgroundColor = th.background;
            p6 = uipanel(g6, 'Title', 'Prescribed stiffness loss', 'BackgroundColor', th.panel, 'FontWeight', 'bold', ...
                'ForegroundColor', th.sageDark);
            p6.Layout.Row = 1;
            p6.Layout.Column = 1;
            f6 = uigridlayout(p6, [12 2]);
            f6.RowHeight = [repmat({26}, 1, 11), {'1x'}];
            f6.ColumnWidth = {170, '1x'};
            f6.BackgroundColor = th.panel;
            f6.Scrollable = 'on';
            c.DamageFromDropDown = app.labeled(f6, 1, 'Damaged region from', uidropdown(f6, 'Items', {'node 1'}, ...
                'Value', 'node 1', 'Tooltip', 'Start of the damaged region (a node)'));
            c.DamageToDropDown = app.labeled(f6, 2, 'Damaged region to', uidropdown(f6, 'Items', {'node 1'}, ...
                'Value', 'node 1', 'Tooltip', 'End of the damaged region (a node to the right of the start)'));
            c.LossField = app.labeled(f6, 3, 'Stiffness loss d [%]', uieditfield(f6, 'numeric', 'Value', 30, ...
                'Limits', [0 99]));
            b = uibutton(f6, 'push', 'Text', 'Apply damage', 'BackgroundColor', th.sage, 'FontColor', th.buttonText, ...
                'FontWeight', 'bold', 'ButtonPushedFcn', @(~, ~) app.applyDamageInputs());
            b.Layout.Row = 4;
            b.Layout.Column = 1;
            b = uibutton(f6, 'push', 'Text', 'Clear damage', 'ButtonPushedFcn', @(~, ~) app.clearDamage());
            b.Layout.Row = 4;
            b.Layout.Column = 2;
            b = uibutton(f6, 'push', 'Text', 'Compare healthy vs damaged (moving load)', 'BackgroundColor', th.sage, ...
                'FontColor', th.buttonText, 'FontWeight', 'bold', 'ButtonPushedFcn', @(~, ~) app.runDamageComparison());
            b.Layout.Row = 5;
            b.Layout.Column = [1 2];
            lbl = uilabel(f6, 'Text', 'Sensitivity: same d moved along the beam', 'FontWeight', 'bold', 'FontColor', th.sageDark);
            lbl.Layout.Row = 6;
            lbl.Layout.Column = [1 2];
            [~, quantityItems] = sensitivityQuantityCode();
            c.SensitivityDropDown = app.labeled(f6, 7, 'Response', uidropdown(f6, 'Items', quantityItems, ...
                'Value', quantityItems{1}));
            c.SupportDropDown = app.labeled(f6, 8, 'Support (for Rmax)', uidropdown(f6, 'Items', {'A'}, 'Value', 'A'));
            [c.SensitivityStepField, c.SensitivityStepLabel] = app.labeled(f6, 9, sprintf('Sweep position step [%s]', ...
                U.length.unit), uieditfield(f6, 'numeric', 'Value', 0.5, 'Limits', [0 Inf], 'LowerLimitInclusive', 'off', ...
                'ValueDisplayFormat', '%.6g'));
            b = uibutton(f6, 'push', 'Text', 'Run sensitivity', 'BackgroundColor', th.sage, 'FontColor', th.buttonText, ...
                'FontWeight', 'bold', 'ButtonPushedFcn', @(~, ~) app.runDamageSensitivity());
            b.Layout.Row = 10;
            b.Layout.Column = [1 2];
            c.DamageInfo = uihtml(f6, 'HTMLSource', infoPanelHtml('message', {'No damage applied.'}));
            c.DamageInfo.Layout.Row = [11 12];
            c.DamageInfo.Layout.Column = [1 2];
            r6 = uigridlayout(g6, [2 1]);
            r6.Layout.Row = 1;
            r6.Layout.Column = 2;
            r6.RowHeight = {170, '1x'};
            r6.BackgroundColor = th.background;
            c.DamageAxes = uiaxes(r6);
            c.DamageAxes.Layout.Row = 1;
            c.DamageAxes.Layout.Column = 1;
            c.DamageResultTabs = uitabgroup(r6);
            c.DamageResultTabs.Layout.Row = 2;
            c.DamageResultTabs.Layout.Column = 1;
            % Sub-tab "Healthy vs damaged": M, V, v envelopes | table and findings
            c.DamageCompareTab = uitab(c.DamageResultTabs, 'Title', 'Healthy vs damaged', 'BackgroundColor', th.background);
            gA = uigridlayout(c.DamageCompareTab, [3 2]);
            gA.ColumnWidth = {'1x', 560};
            gA.RowHeight = {'1x', '1x', '1x'};
            gA.BackgroundColor = th.background;
            c.DamageMomentAxes = uiaxes(gA);
            c.DamageMomentAxes.Layout.Row = 1;
            c.DamageMomentAxes.Layout.Column = 1;
            c.DamageShearAxes = uiaxes(gA);
            c.DamageShearAxes.Layout.Row = 2;
            c.DamageShearAxes.Layout.Column = 1;
            c.DamageDeflectionAxes = uiaxes(gA);
            c.DamageDeflectionAxes.Layout.Row = 3;
            c.DamageDeflectionAxes.Layout.Column = 1;
            c.DamageTable = uitable(gA, 'Data', cell(0, 5), 'ColumnName', ...
                {'Quantity', 'Healthy', 'Damaged', 'Change', 'Change [%]'}, 'RowName', {}, 'ColumnWidth', 'fit');
            c.DamageTable.Layout.Row = [1 2];
            c.DamageTable.Layout.Column = 2;
            c.DamageFindings = uihtml(gA, 'HTMLSource', infoPanelHtml('message', {'Press "Compare healthy vs damaged".'}));
            c.DamageFindings.Layout.Row = 3;
            c.DamageFindings.Layout.Column = 2;
            % Sub-tab "Sensitivity along the beam": bar chart | ranking table
            c.DamageSensitivityTab = uitab(c.DamageResultTabs, 'Title', 'Sensitivity along the beam', ...
                'BackgroundColor', th.background);
            gB = uigridlayout(c.DamageSensitivityTab, [1 2]);
            gB.ColumnWidth = {'1x', 560};
            gB.BackgroundColor = th.background;
            c.SensitivityAxes = uiaxes(gB);
            c.SensitivityAxes.Layout.Row = 1;
            c.SensitivityAxes.Layout.Column = 1;
            gB2 = uigridlayout(gB, [2 1]);
            gB2.Layout.Row = 1;
            gB2.Layout.Column = 2;
            gB2.RowHeight = {'1x', 32};
            gB2.Padding = [0 0 0 0];
            gB2.BackgroundColor = th.background;
            c.SensitivityTable = uitable(gB2, 'Data', cell(0, 6), 'ColumnName', {}, 'RowName', {}, 'ColumnWidth', 'fit');
            c.SensitivityTable.Layout.Row = 1;
            c.SensitivityTable.Layout.Column = 1;
            c.SensitivityLegend = app.legendLabel(gB2, 2, 1, app.xLegendText('sensitivity'));

            % ---- Tab: Identification (Stage 3)
            t7 = uitab(tabs, 'Title', 'Identification (Stage 3)', 'BackgroundColor', th.background);
            g7 = uigridlayout(t7, [1 2]);
            g7.ColumnWidth = {460, '1x'};   % every tab: room for the reactions table and long names
            g7.BackgroundColor = th.background;
            p7 = uipanel(g7, 'Title', 'Sensors, readings and search', 'BackgroundColor', th.panel, 'FontWeight', 'bold', ...
                'ForegroundColor', th.sageDark);
            p7.Layout.Row = 1;
            p7.Layout.Column = 1;
            f7 = uigridlayout(p7, [15 2]);
            f7.RowHeight = {18, 136, 26, 18, 26, 26, 26, 26, 26, 18, 26, 26, 26, 30, '1x'};
            f7.RowSpacing = 6;
            f7.ColumnWidth = {170, '1x'};
            f7.BackgroundColor = th.panel;
            f7.Scrollable = 'on';
            c.SensorsTable = app.pointTable(f7, 1, 'Sensors (x on the bridge)', sprintf('x [%s]', U.length.unit), 'sensor');
            c.PositionsTable = app.pointTable(f7, 2, 'Truck positions (front axle)', sprintf('x_v [%s]', U.length.unit), ...
                'truck position');
            lbl = uilabel(f7, 'Text', 'Synthetic test case (hidden from the search)', 'FontWeight', 'bold', ...
                'FontColor', th.sageDark);
            lbl.Layout.Row = 4;
            lbl.Layout.Column = [1 2];
            c.HiddenFromDropDown = app.labeled(f7, 5, 'Hidden region from', uidropdown(f7, 'Items', {'node 1'}, ...
                'Value', 'node 1'));
            c.HiddenToDropDown = app.labeled(f7, 6, 'Hidden region to', uidropdown(f7, 'Items', {'node 1'}, ...
                'Value', 'node 1'));
            c.HiddenLossField = app.labeled(f7, 7, 'Hidden loss d [%]', uieditfield(f7, 'numeric', 'Value', 30, ...
                'Limits', [0 60], 'Tooltip', 'The search covers losses of 5 to 60 %; 0 gives an undamaged case'));
            lbl = uilabel(f7, 'Text', 'Noise added [% of reading]', 'FontColor', th.text);
            lbl.Layout.Row = 8;
            lbl.Layout.Column = 1;
            noiseRow = uigridlayout(f7, [1 3]);         % noise and seed share a row
            noiseRow.Layout.Row = 8;
            noiseRow.Layout.Column = 2;
            noiseRow.ColumnWidth = {'1x', 34, 80};
            noiseRow.Padding = [0 0 0 0];
            noiseRow.ColumnSpacing = 6;
            noiseRow.BackgroundColor = th.panel;
            c.SyntheticNoiseField = uieditfield(noiseRow, 'numeric', 'Value', 1, 'Limits', [0 50]);
            c.SyntheticNoiseField.Layout.Row = 1;
            c.SyntheticNoiseField.Layout.Column = 1;
            lbl = uilabel(noiseRow, 'Text', 'seed', 'HorizontalAlignment', 'right', 'FontColor', th.text);
            lbl.Layout.Row = 1;
            lbl.Layout.Column = 2;
            c.SeedField = uieditfield(noiseRow, 'numeric', 'Value', 1, 'Limits', [0 1e9], 'RoundFractionalValues', 'on', ...
                'Tooltip', 'Noise seed: the same seed gives the same readings (also in Octave)');
            c.SeedField.Layout.Row = 1;
            c.SeedField.Layout.Column = 3;
            b = uibutton(f7, 'push', 'Text', 'Generate synthetic readings', 'BackgroundColor', th.sage, ...
                'FontColor', th.buttonText, 'FontWeight', 'bold', 'ButtonPushedFcn', @(~, ~) app.generateSyntheticReadings());
            b.Layout.Row = 9;
            b.Layout.Column = 1;
            b = uibutton(f7, 'push', 'Text', 'New empty table', 'Tooltip', 'For measured readings', ...
                'ButtonPushedFcn', @(~, ~) app.newEmptyReadings());
            b.Layout.Row = 9;
            b.Layout.Column = 2;
            lbl = uilabel(f7, 'Text', 'Search', 'FontWeight', 'bold', 'FontColor', th.sageDark);
            lbl.Layout.Row = 10;
            lbl.Layout.Column = [1 2];
            c.SearchNoiseField = app.labeled(f7, 11, 'Reading noise [% of reading]', uieditfield(f7, 'numeric', ...
                'Value', 1, 'Limits', [0 50], 'Tooltip', app.noiseTooltip()));
            [c.SearchNoiseAbsField, c.SearchNoiseAbsLabel] = app.labeled(f7, 12, sprintf('Reading noise [%s]', ...
                U.deflection.unit), uieditfield(f7, 'numeric', 'Value', 0, 'Limits', [0 Inf], ...
                'ValueDisplayFormat', '%.6g', 'Tooltip', 'Absolute part of the standard deviation (sensor resolution)'));
            [~, regionItems] = candidateRegionLength([], U);
            c.RegionSizeDropDown = app.labeled(f7, 13, 'Candidate regions', uidropdown(f7, 'Items', regionItems, ...
                'Value', regionItems{1}));
            b = uibutton(f7, 'push', 'Text', 'Run identification', 'BackgroundColor', th.sage, 'FontColor', th.buttonText, ...
                'FontWeight', 'bold', 'ButtonPushedFcn', @(~, ~) app.runIdentification());
            b.Layout.Row = 14;
            b.Layout.Column = [1 2];
            c.IdentInfo = uihtml(f7, 'HTMLSource', infoPanelHtml('message', {'Press "Run identification".'}));
            c.IdentInfo.Layout.Row = 15;
            c.IdentInfo.Layout.Column = [1 2];
            r7 = uigridlayout(g7, [2 1]);
            r7.Layout.Row = 1;
            r7.Layout.Column = 2;
            r7.RowHeight = {190, '1x'};
            r7.BackgroundColor = th.background;
            c.IdentAxes = uiaxes(r7);
            c.IdentAxes.Layout.Row = 1;
            c.IdentAxes.Layout.Column = 1;
            c.IdentResultTabs = uitabgroup(r7);
            c.IdentResultTabs.Layout.Row = 2;
            c.IdentResultTabs.Layout.Column = 1;
            c.IdentReadingsTab = uitab(c.IdentResultTabs, 'Title', sprintf('Readings [%s]', U.deflection.unit), ...
                'BackgroundColor', th.background);
            gR = uigridlayout(c.IdentReadingsTab, [2 2]);
            gR.ColumnWidth = {640, '1x'};        % room for five truck-position columns without scrolling
            gR.RowHeight = {'1x', 18};
            gR.BackgroundColor = th.background;
            c.ReadingsLegend = app.legendLabel(gR, 2, [1 2], app.xLegendText('readings'));
            c.ReadingsTable = uitable(gR, 'Data', zeros(0, 0), 'ColumnWidth', 'fit', ...
                'CellEditCallback', @(~, ~) app.onReadingsEdited());
            c.ReadingsTable.Layout.Row = 1;
            c.ReadingsTable.Layout.Column = 1;
            c.ReadingsAxes = uiaxes(gR);
            c.ReadingsAxes.Layout.Row = 1;
            c.ReadingsAxes.Layout.Column = 2;
            c.IdentFitTab = uitab(c.IdentResultTabs, 'Title', 'Fit by location', 'BackgroundColor', th.background);
            gF = uigridlayout(c.IdentFitTab, [3 1]);
            gF.RowHeight = {'1x', 210, 18};
            gF.BackgroundColor = th.background;
            c.FitAxes = uiaxes(gF);
            c.FitAxes.Layout.Row = 1;
            c.FitAxes.Layout.Column = 1;
            c.CandidateTable = uitable(gF, 'Data', cell(0, 7), 'RowName', {}, 'ColumnWidth', 'fit', 'ColumnName', {});
            c.CandidateTable.Layout.Row = 2;
            c.CandidateTable.Layout.Column = 1;
            c.CandidateLegend = app.legendLabel(gF, 3, 1, app.xLegendText('candidates'));
            % Sub-tab "Summary": the full plain-language result at full width
            c.IdentSummaryTab = uitab(c.IdentResultTabs, 'Title', 'Summary', 'BackgroundColor', th.background);
            gS = uigridlayout(c.IdentSummaryTab, [1 1]);
            gS.BackgroundColor = th.background;
            c.IdentResultText = uihtml(gS, 'HTMLSource', ...
                infoPanelHtml('message', {'Press "Run identification": the result appears here.'}));
            c.IdentResultText.Layout.Row = 1;
            c.IdentResultText.Layout.Column = 1;

            % ---- Tab 4: Matrices
            t4 = uitab(tabs, 'Title', 'Matrices', 'BackgroundColor', th.background);
            g4 = uigridlayout(t4, [3 2]);
            g4.RowHeight = {30, '1x', '1x'};
            g4.ColumnWidth = {'1x', '1x'};
            g4.BackgroundColor = th.background;
            top = uigridlayout(g4, [1 4]);
            top.Layout.Row = 1;
            top.Layout.Column = [1 2];
            top.ColumnWidth = {60, 80, 120, '1x'};
            top.Padding = [0 0 0 0];
            top.BackgroundColor = th.background;
            lbl = uilabel(top, 'Text', 'Element');
            lbl.Layout.Row = 1;
            lbl.Layout.Column = 1;
            c.ElementSpinner = uispinner(top, 'Value', 1, 'Limits', [1 2], 'RoundFractionalValues', 'on', ...
                'ValueChangedFcn', @(~, ~) app.showMatrices());
            c.ElementSpinner.Layout.Row = 1;
            c.ElementSpinner.Layout.Column = 2;
            b = uibutton(top, 'push', 'Text', 'Refresh', 'ButtonPushedFcn', @(~, ~) app.showMatrices());
            b.Layout.Row = 1;
            b.Layout.Column = 3;
            c.MatrixInfo = uilabel(top, 'Text', '', 'FontColor', th.text);
            c.MatrixInfo.Layout.Row = 1;
            c.MatrixInfo.Layout.Column = 4;
            c.KeTable = app.titledTable(g4, 2, 1, 'Element stiffness matrix k_e (DOFs v_i, theta_i, v_j, theta_j)');
            c.DofTable = app.titledTable(g4, 2, 2, 'DOF status and vectors: F (applied), U (solution), R (reactions)');
            c.KTable = app.titledTable(g4, 3, [1 2], 'Global stiffness matrix K = sum A_e'' k_e A_e (before supports)');

            % ---- Tab 5: Verification
            t5 = uitab(tabs, 'Title', 'Verification', 'BackgroundColor', th.background);
            g5 = uigridlayout(t5, [2 1]);
            g5.RowHeight = {34, '1x'};
            g5.BackgroundColor = th.background;
            b = uibutton(g5, 'push', 'Text', 'Run all tests (runAllTests)', 'BackgroundColor', th.sage, ...
                'FontColor', th.buttonText, 'FontWeight', 'bold', 'ButtonPushedFcn', @(~, ~) app.runVerification());
            b.Layout.Row = 1;
            b.Layout.Column = 1;
            c.VerificationArea = uitextarea(g5, 'Editable', 'off', 'FontName', 'Courier New', ...
                'Value', {'Runs the analytical benchmark and unit tests. Recorded results: VERIFICATION_LOG.md.'});
            c.VerificationArea.Layout.Row = 2;
            c.VerificationArea.Layout.Column = 1;
            app.Controls = c;
        end

        function scale = responseScale(app, code)
            % A physical size of a response (SI) to judge round-off against: total load P (axles plus the uniform
            % load), P*L for moments, P*L^3/EI for deflections.
            x = app.Model.nodes.x;
            L = x(end) - x(1);
            w = sum(abs(app.Model.loads.elementUDL(:)) .* diff(x(:)));   % total permanent uniform load [N]
            P = sum(abs(app.Vehicle.axleLoads)) + w;
            switch code(1)
                case 'M'
                    scale = P * L;
                case 'v'
                    scale = P * L^3 / min(effectiveEI(app.Model));
                otherwise
                    scale = P;
            end
        end

        function lbl = legendLabel(app, grid, row, column, text)
            % Small grey line under a table that says what x and x_v mean.
            lbl = uilabel(grid, 'Text', text, 'FontSize', 11, 'FontColor', [0.40 0.40 0.40], 'WordWrap', 'on', ...
                'BackgroundColor', app.Theme.background);
            lbl.Layout.Row = row;
            lbl.Layout.Column = column;
        end

        function text = xLegendText(~, which)
            % What x and x_v mean, next to the tables that use them.
            switch which
                case 'critical'
                    text = ['x = location on the bridge where the extreme occurs; x_v = position of the truck''s front ' ...
                        'axle that causes it (both measured from support A).'];
                case 'reaction'
                    text = 'x = location of the support; at x_v = front-axle position of the truck that gives the extreme.';
                case 'sensitivity'
                    text = ['x = location of the weakened element(s) on the bridge, measured from support A. Change = ' ...
                        'damaged - healthy value of the response, in its unit.'];
                case 'readings'
                    text = ['Rows: sensors S1, S2, ... at x on the bridge. Columns: truck front-axle positions x_v. ' ...
                        'Both measured from support A.'];
                case 'candidates'
                    text = 'Region x = start-end of the candidate region on the bridge, measured from support A.';
            end
        end

        function tbl = pointTable(app, grid, column, titleText, header, kind)
            % Table of coordinates (sensors or truck positions) with "+ Add" and "- Remove" under it.
            th = app.Theme;
            lbl = uilabel(grid, 'Text', titleText, 'FontWeight', 'bold', 'FontColor', th.sageDark);
            lbl.Layout.Row = 1;
            lbl.Layout.Column = column;
            tbl = uitable(grid, 'Data', cell(0, 1), 'ColumnName', {header}, 'ColumnEditable', true, ...
                'ColumnFormat', {'numeric'}, 'FontSize', 11, 'CellEditCallback', @(~, ~) app.onIdentPointsEdited());
            tbl.Layout.Row = 2;
            tbl.Layout.Column = column;
            buttons = uigridlayout(grid, [1 2]);
            buttons.Layout.Row = 3;
            buttons.Layout.Column = column;
            buttons.Padding = [0 0 0 0];
            buttons.ColumnSpacing = 4;
            buttons.BackgroundColor = th.panel;
            b = uibutton(buttons, 'push', 'Text', '+ Add', 'FontColor', th.sage, 'FontWeight', 'bold', ...
                'Tooltip', sprintf('Add a %s after the last one (edit its value in the table)', kind), ...
                'ButtonPushedFcn', @(~, ~) app.addIdentPoint(kind));
            b.Layout.Row = 1;
            b.Layout.Column = 1;
            b = uibutton(buttons, 'push', 'Text', '- Remove', 'Tooltip', sprintf('Remove the last %s', kind), ...
                'ButtonPushedFcn', @(~, ~) app.removeIdentPoint(kind));
            b.Layout.Row = 1;
            b.Layout.Column = 2;
        end

        function setPointTable(~, tbl, values, prefix)
            % Write coordinates (display units) into a one-column table with rows PREFIX1, PREFIX2, ...
            values = values(:)';
            data = cell(numel(values), 1);
            for k = 1:numel(values)
                data{k} = values(k);
            end
            tbl.Data = data;
            tbl.RowName = arrayfun(@(k) sprintf('%s%d', prefix, k), 1:numel(values), 'UniformOutput', false);
        end

        function [tbl, prefix, limits, noun] = identPointTable(app, kind)
            % The sensor or the truck-position table, its row prefix and the range of a new entry (display units).
            c = app.Controls;
            if strcmp(kind, 'sensor')
                tbl = c.SensorsTable;
                prefix = 'S';
                limits = [app.Model.nodes.x(1), app.Model.nodes.x(end)] / app.Units.length.toSI;
                noun = 'sensor';
            else
                tbl = c.PositionsTable;
                prefix = 'P';
                limits = app.PositionRange / app.Units.length.toSI;
                noun = 'truck position';
            end
        end

        function ok = readsSomething(app, kind, x)
            % True when a sensor at x (or the truck at front-axle position x) gives a non-zero healthy reading
            % for at least one of the other table entries (display units).
            c = app.Controls;
            U = app.Units;
            sensors = app.tableNumbers(c.SensorsTable.Data, 1);
            positions = app.tableNumbers(c.PositionsTable.Data, 1);
            sensors = sensors(~isnan(sensors));
            positions = positions(~isnan(positions));
            L = app.Model.nodes.x;
            sensors = sensors(sensors * U.length.toSI >= L(1) & sensors * U.length.toSI <= L(end));
            if strcmp(kind, 'sensor')
                sensors = x;
            else
                positions = x;
            end
            ok = true;
            if isempty(sensors) || isempty(positions)
                return
            end
            u = predictSensorDeflections(app.Model, app.Vehicle, positions * U.length.toSI, sensors * U.length.toSI, ...
                app.Direction);
            uAll = predictSensorDeflections(app.Model, app.Vehicle, app.PositionRange(1) + (app.PositionRange(2) - ...
                app.PositionRange(1)) * (0.2:0.2:0.8), (L(1) + L(end)) / 2, app.Direction);
            ok = max(abs(u(:))) > 1e-9 * max(abs(uAll(:)));
        end

        function onIdentPointsEdited(app)
            if ~isempty(app.IdentResult)
                app.clearIdentificationResults();       % the old result belongs to the old sensors / positions
            end
            app.drawIdentification();
            app.setStatus(['Sensors or truck positions edited: press "Generate synthetic readings" or "New empty table" ' ...
                'for a readings table that matches them.']);
        end

        function checkZeroReadings(app, sensors, positions, uObs)
            % With a reading noise in % only, a reading predicted as zero gets no standard deviation and the engine
            % refuses the run with a message about an option the app does not show ('NoiseAbsolute'): name the
            % truck position, the sensor or the reading in the app's words. Missing readings (NaN in uObs) are
            % left out, as in the engine. A truck position is named first: with no axle inside a span, every
            % sensor reads zero, and the sensors are not at fault.
            c = app.Controls;
            if c.SearchNoiseField.Value <= 0 || c.SearchNoiseAbsField.Value > 0
                return
            end
            U = app.Units;
            uH = predictSensorDeflections(app.Model, app.Vehicle, positions, sensors, app.Direction);
            known = ~isnan(uObs);
            zero = known & abs(uH) <= 1e-12 * max(abs(uH(:)));
            if ~any(zero(:))
                return
            end
            p = find(all(zero | ~known, 1) & any(known, 1), 1);
            if ~isempty(p)
                error('BridgeFE:invalidInput', ['Truck position %d (x_v = %g %s) gives zero readings at every sensor ' ...
                    '(no axle inside a span). Remove it, or state Reading noise [%s] > 0.'], p, ...
                    positions(p) / U.length.toSI, U.length.unit, U.deflection.unit);
            end
            s = find(all(zero | ~known, 2) & any(known, 2), 1);
            if ~isempty(s)
                x = app.Model.nodes.x;
                if any(abs(app.ModelInfo.supportX(:) - sensors(s)) <= 1e-6 * (x(end) - x(1)))
                    why = 'it is on a support';
                else
                    why = 'no truck position loads its span';
                end
                error('BridgeFE:invalidInput', ['Sensor %d (x = %g %s) reads zero for every truck position (%s). ' ...
                    'Remove it, or state Reading noise [%s] > 0.'], s, sensors(s) / U.length.toSI, U.length.unit, ...
                    why, U.deflection.unit);
            end
            [s, p] = find(zero, 1);
            error('BridgeFE:invalidInput', ['Sensor %d (x = %g %s) reads zero with the truck at position %d (x_v = %g ' ...
                '%s): no axle loads its span (e.g. beyond a Fixed support). With a reading noise in %% only, a zero ' ...
                'reading has no noise level: state Reading noise [%s] > 0, or leave that reading empty (missing).'], ...
                s, sensors(s) / U.length.toSI, U.length.unit, p, positions(p) / U.length.toSI, U.length.unit, ...
                U.deflection.unit);
        end

        function checkRegionOrder(~, fromDropDown, toDropDown, name)
            % A region runs from a node to a node on its right; the message quotes the drop-downs (display units).
            if find(strcmp(toDropDown.Items, toDropDown.Value)) <= find(strcmp(fromDropDown.Items, fromDropDown.Value))
                error('BridgeFE:invalidInput', '%s: choose a "to" node to the right of the "from" node (now from %s to %s).', ...
                    name, fromDropDown.Value, toDropDown.Value);
            end
        end

        function [ctrl, lbl] = labeled(app, grid, row, text, ctrl)
            lbl = uilabel(grid, 'Text', text, 'FontColor', app.Theme.text);
            lbl.Layout.Row = row;
            lbl.Layout.Column = 1;
            ctrl.Layout.Row = row;
            ctrl.Layout.Column = 2;
        end

        function tbl = titledTable(app, grid, row, column, titleText)
            p = uipanel(grid, 'Title', titleText, 'BackgroundColor', app.Theme.panel, 'ForegroundColor', app.Theme.sageDark);
            p.Layout.Row = row;
            p.Layout.Column = column;
            inner = uigridlayout(p, [1 1]);
            inner.Padding = [2 2 2 2];
            tbl = uitable(inner, 'Data', cell(0, 0));
            tbl.Layout.Row = 1;
            tbl.Layout.Column = 1;
        end

        function onMaterialChanged(app)
            % Material drop-down: Is or Ieff label, and the other material's default E becomes this one's.
            c = app.Controls;
            U = app.Units;
            steelE = 200e9 / U.modulus.toSI;            % default moduli in the display unit
            rccE = 30e9 / U.modulus.toSI;
            same = @(a, b) abs(a - b) <= 1e-9 * abs(b);
            app.updateInertiaLabel();
            if strcmp(c.MaterialDropDown.Value, 'RCC')
                if same(c.EField.Value, steelE)
                    c.EField.Value = rccE;
                end
            elseif same(c.EField.Value, rccE)
                c.EField.Value = steelE;
            end
            app.previewModel();                         % the material is a model input: show it before Apply
        end

        function updateInertiaLabel(app)
            % Is (steel) or Ieff (RCC) in the current unit; E is left as typed (a unit switch uses this).
            c = app.Controls;
            name = 'Is';
            if strcmp(c.MaterialDropDown.Value, 'RCC')
                name = 'Ieff';
            end
            c.ILabel.Text = sprintf('%s [%s]', name, app.Units.inertia.unit);
        end

        function text = noiseTooltip(app)
            text = sprintf('Standard deviation of each reading; 0 %% and 0 %s = no noise-based region', ...
                app.Units.deflection.unit);
        end

        function xv = startPosition(app)
            if app.Direction > 0
                xv = app.PositionRange(1);
            else
                xv = app.PositionRange(2);
            end
        end

        function redrawAll(app)
            if app.Previewing
                app.previewModel(true);                 % keep showing the un-applied edits
            elseif ~isempty(app.Model)
                app.drawModelTab();
            end
            if ~isempty(app.Model)
                app.drawDamageModel();                  % node numbers on the Damage drawing too
            end
            if ~isempty(app.PositionResult)
                app.drawPositionView();
            end
        end
    end
end
