classdef BridgeConditionApp < handle
    %BRIDGECONDITIONAPP Sage-green MATLAB app for the CE 7405 equivalent-beam bridge analysis (M6).
    %   APP = BRIDGECONDITIONAPP() opens the app window. It is a code-built
    %   app: the same components App Designer uses (UIFIGURE, UIGRIDLAYOUT,
    %   UITAB, UIAXES, ...) written as plain text (DECISIONS.md D-023).
    %   There are no calculations in the app. Every number comes from the
    %   verified engine in src/ (buildModelFromInputs, prepareMovingLoad,
    %   analyzeVehiclePosition, runMovingLoad, solveStaticModel), and every
    %   drawing from the tested bridgeDrawing and responseDiagramData.
    %
    %   Tabs:
    %     Bridge model         spans, mesh, supports (pin / roller / fixed /
    %                          none), steel Es*Is or RCC Ec*Ieff, permanent
    %                          uniform load; drawing with conventional supports
    %     Vehicle & moving load axles and spacings, position slider; truck
    %                          schematic, deformed shape (stated magnification),
    %                          M, V and v diagrams, reactions at that position
    %     Envelopes            quasi-static crossing: max/min M, V, v envelopes,
    %                          critical vehicle positions, reaction envelopes
    %     Damage (Stage 2)     prescribed EI loss EI_D = (1 - d) EI on a region;
    %                          healthy vs damaged envelopes and reactions; a
    %                          sensitivity sweep moving the same loss along the beam
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
    %   See also BUILDMODELFROMINPUTS, RUNMOVINGLOAD, BRIDGEDRAWING.

    properties (SetAccess = private)
        UIFigure                  % app window
        Controls = struct()       % handles of all input and output components
        Model = []                % current beam model (createBeamModel struct)
        ModelInfo = []            % summary and warnings from buildModelFromInputs
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
    end

    properties (Access = private)
        Theme
        PositionRange = [0 1]
        DirectionItems = {'+x (left to right)', '-x (right to left)'}
    end

    methods
        function app = BridgeConditionApp()
            if exist('createBeamModel', 'file') ~= 2
                root = fileparts(fileparts(mfilename('fullpath')));
                addpath(root);
                addProjectPaths();
            end
            app.Theme = appTheme();
            app.createComponents();
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
            in = struct('spans', c.SpansField.Value, 'elementsPerSpan', c.ElementsField.Value, ...
                'supports', c.SupportsField.Value, 'materialType', lower(c.MaterialDropDown.Value), ...
                'E_GPa', c.EField.Value, 'I_m4', c.IField.Value, 'materialName', c.MaterialNameField.Value, ...
                'materialBasis', c.BasisField.Value, 'udlDown_kNpm', c.UDLField.Value);
            try
                [model, info] = buildModelFromInputs(in);
            catch err
                ok = app.reportError(err, 'Model input');
                return
            end
            app.Model = model;
            app.ModelInfo = info;
            app.MovingLoad = [];
            app.StaticResult = [];
            app.LastError = '';
            c.SummaryArea.Value = info.summary;
            app.drawModelTab();
            if ~isempty(info.warnings)
                uialert(app.UIFigure, strjoin(info.warnings, ' '), 'Check units', 'Icon', 'warning');
            end
            ok = true;
            if ~isempty(app.Vehicle)
                ok = app.resetMovingLoad();
            end
            app.clearEnvelopes();
            app.clearDamage();
            app.setStatus(sprintf('Model applied: %s', info.summary{2}));
        end

        function ok = applyVehicleInputs(app)
            %APPLYVEHICLEINPUTS Build the vehicle from the Vehicle tab (button "Apply vehicle").
            c = app.Controls;
            try
                vehicle = vehicleFromInputs(c.AxleLoadsField.Value, c.SpacingsField.Value, c.VehicleNameField.Value);
                assertPositiveFiniteScalar(c.StepField.Value, 'Position step [m]');
            catch err
                ok = app.reportError(err, 'Vehicle input');
                return
            end
            app.Vehicle = vehicle;
            app.Step = c.StepField.Value;
            app.Direction = 1;
            if strcmp(c.DirectionDropDown.Value, app.DirectionItems{2})
                app.Direction = -1;
            end
            app.MovingLoad = [];
            app.LastError = '';
            app.clearEnvelopes();
            app.clearDamageResults();
            ok = true;
            if ~isempty(app.Model)
                ok = app.resetMovingLoad();
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
            c.PositionSlider.Value = xv;
            c.PositionLabel.Text = sprintf('x_v = %.3f m (front axle), %d of %d axles on the bridge', ...
                xv, nnz(res.axles.onBridge), numel(res.axles.x));
            app.drawPositionView();
            [data, columns] = currentReactionTableData(res, app.Model);
            c.ReactionsTable.Data = data;
            c.ReactionsTable.ColumnName = columns;
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
            app.setStatus(sprintf('Envelopes: %d positions (step %.4g m) + %d refined positions.', ...
                ml.nCoarse, ml.step, ml.nRefined));
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
                [damaged, ~, info] = damageModelFromInputs(app.Model, c.DamageFromField.Value, ...
                    c.DamageToField.Value, c.LossField.Value);
            catch err
                ok = app.reportError(err, 'Damage input');
                return
            end
            app.DamagedModel = damaged;
            app.LastError = '';
            app.clearDamageResults();
            app.drawDamageModel();
            c.DamageInfo.Value = {info.summary; ...
                'd reduces MODEL flexural rigidity; it is not a percentage of corrosion, section loss or capacity.'};
            app.setStatus(['Damage applied: ' info.summary]);
            ok = true;
        end

        function clearDamage(app)
            %CLEARDAMAGE Remove the prescribed loss (button "Clear damage"); the healthy model is unchanged.
            app.DamagedModel = [];
            app.clearDamageResults();
            if ~isempty(app.Model)
                app.drawDamageModel();
            end
            app.Controls.DamageInfo.Value = {'No damage applied. Choose a region on nodes and a loss d, then press Apply damage.'};
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
            h = cmp.healthy.envelope;
            d = cmp.damaged.envelope;
            plotEnvelopeComparison(c.DamageMomentAxes, cmp.stations, h.Mmax / 1e3, h.Mmin / 1e3, d.Mmax / 1e3, ...
                d.Mmin / 1e3, th.text, th.damage, 'M [kN*m]', 'Moment envelope');
            plotEnvelopeComparison(c.DamageShearAxes, cmp.stations, h.Vmax / 1e3, h.Vmin / 1e3, d.Vmax / 1e3, ...
                d.Vmin / 1e3, th.text, th.damage, 'V [kN]', 'Shear envelope');
            plotEnvelopeComparison(c.DamageDeflectionAxes, cmp.stations, h.vmax * 1e3, h.vmin * 1e3, d.vmax * 1e3, ...
                d.vmin * 1e3, th.text, th.damage, 'v [mm]', 'Deflection envelope');
            [data, columns] = damageComparisonTableData(cmp);
            c.DamageTable.Data = data;
            c.DamageTable.ColumnName = columns;
            c.DamageFindings.Value = damageComparisonSummary(cmp, app.Model);
            c.DamageResultTabs.SelectedTab = c.DamageCompareTab;
            app.setStatus(sprintf('Healthy vs damaged: %d positions per model. Healthy dashed, damaged solid.', ...
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
                opts = {'Step', max(app.Step, c.SensitivityStepField.Value), 'Direction', app.Direction, 'Refine', false};
                if strcmp(code, 'Rmax')
                    opts = [opts, {'Node', round(c.SupportNodeField.Value)}];
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
            plotSensitivity(c.SensitivityAxes, s, app.Model, app.Theme.damage);
            [data, columns] = sensitivityTableData(s, app.Model);
            c.SensitivityTable.Data = data;
            c.SensitivityTable.ColumnName = columns;
            c.DamageResultTabs.SelectedTab = c.DamageSensitivityTab;
            app.setStatus(sprintf('Sensitivity: d = %g %% moved over %d locations; most influential: element(s) %s.', ...
                100 * d, numel(s.groups), data{1, 2}));
            ok = true;
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
            s.Limits = app.PositionRange;
            s.Value = xv(1);
            app.setVehiclePosition(xv(1));
            ok = true;
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
            prims = bridgeDrawing(app.Model, struct('SymbolSize', app.symbolSize(), ...
                'ShowNumbers', c.NumbersCheckBox.Value, 'Theme', app.Theme));
            cla(c.ModelAxes);
            renderDrawing(c.ModelAxes, prims);
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
            opts = struct('SymbolSize', h, 'ShowNumbers', c.NumbersCheckBox.Value, 'Axles', res.axles, ...
                'Direction', app.Direction, 'Deformed', struct('x', d.x, 'y', d.v * magnification), ...
                'DeformedLabel', sprintf('deformed shape (dashed) x %.4g', magnification), 'Theme', th);
            cla(c.BeamAxes);
            renderDrawing(c.BeamAxes, bridgeDrawing(app.Model, opts));
            title(c.BeamAxes, sprintf('%s at x_v = %.3f m (quasi-static)', app.Vehicle.name, app.Position));
            plotDiagram(c.MomentAxes, d.x, d.M / 1e3, th.moment, 'M [kN*m]', 'Bending moment (+ sagging)');
            plotDiagram(c.ShearAxes, d.x, d.V / 1e3, th.shear, 'V [kN]', 'Shear force');
            plotDiagram(c.DeflectionAxes, d.x, d.v * 1e3, th.deflection, 'v [mm]', 'Vertical deflection (+ up)');
        end

        function drawEnvelopes(app)
            c = app.Controls;
            th = app.Theme;
            ml = app.MovingLoad;
            e = ml.envelope;
            x = ml.stations;
            cr = ml.critical;
            plotEnvelope(c.EnvMomentAxes, x, e.Mmax / 1e3, e.Mmin / 1e3, th.envelopeMax, th.envelopeMin, ...
                'M [kN*m]', 'Moment envelope (+ sagging)', [cr(1:2).x], [cr(1:2).value] / 1e3);
            plotEnvelope(c.EnvShearAxes, x, e.Vmax / 1e3, e.Vmin / 1e3, th.envelopeMax, th.envelopeMin, ...
                'V [kN]', 'Shear envelope', [cr(3:4).x], [cr(3:4).value] / 1e3);
            plotEnvelope(c.EnvDeflectionAxes, x, e.vmax * 1e3, e.vmin * 1e3, th.envelopeMax, th.envelopeMin, ...
                'v [mm]', 'Deflection envelope (+ up)', [cr(5:6).x], [cr(5:6).value] * 1e3);
            [data, columns] = criticalTableData(ml);
            c.CriticalTable.Data = data;
            c.CriticalTable.ColumnName = columns;
            [data, columns] = reactionEnvelopeTableData(ml, app.Model.nodes.x);
            c.EnvReactionsTable.Data = data;
            c.EnvReactionsTable.ColumnName = columns;
            v = ml.vehicle;
            c.EnvelopeInfo.Value = { ...
                sprintf('%s: axle loads %s kN, spacings %s m (front axle = x_v).', v.name, ...
                    mat2str(v.axleLoads.' / 1e3), mat2str(v.axleSpacings.')); ...
                sprintf('%d positions at step %.4g m plus %d refined positions; travel %s.', ...
                    ml.nCoarse, ml.step, ml.nRefined, app.DirectionItems{(3 - ml.direction) / 2}); ...
                'Permanent model loads are included at every position. Quasi-static: no impact or dynamic effects.'};
        end

        function clearDamageResults(app)
            c = app.Controls;
            app.DamageComparison = [];
            app.DamageSensitivity = [];
            c.DamageTable.Data = cell(0, 5);
            c.SensitivityTable.Data = cell(0, 6);
            c.DamageFindings.Value = {'Press "Compare healthy vs damaged" to fill the plots, the table and these findings.'};
            names = {'DamageMomentAxes', 'DamageShearAxes', 'DamageDeflectionAxes', 'SensitivityAxes'};
            hints = {'Moment envelope (press Compare)', 'Shear envelope (press Compare)', ...
                'Deflection envelope (press Compare)', 'Sensitivity (press Run sensitivity)'};
            for k = 1:numel(names)
                cla(c.(names{k}));
                title(c.(names{k}), hints{k});
            end
        end

        function drawDamageModel(app)
            c = app.Controls;
            factor = [];
            if ~isempty(app.DamagedModel)
                factor = app.DamagedModel.elements.stiffnessFactor;
            end
            prims = bridgeDrawing(app.Model, struct('SymbolSize', app.symbolSize(), 'StiffnessFactor', factor, ...
                'ShowNumbers', c.NumbersCheckBox.Value, 'Theme', app.Theme));
            cla(c.DamageAxes);
            renderDrawing(c.DamageAxes, prims);
            title(c.DamageAxes, 'Damaged region (prescribed EI loss) on the healthy model');
        end

        function clearEnvelopes(app)
            c = app.Controls;
            c.CriticalTable.Data = cell(0, 7);
            c.EnvReactionsTable.Data = cell(0, 7);
            c.EnvelopeInfo.Value = {'Press "Run moving-load analysis" to compute envelopes for the current model and vehicle.'};
            cla(c.EnvMomentAxes);
            cla(c.EnvShearAxes);
            cla(c.EnvDeflectionAxes);
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
            t1 = uitab(tabs, 'Title', 'Bridge model', 'BackgroundColor', th.background);
            g1 = uigridlayout(t1, [1 2]);
            g1.ColumnWidth = {360, '1x'};
            g1.BackgroundColor = th.background;
            p1 = uipanel(g1, 'Title', 'Model input', 'BackgroundColor', th.panel, 'FontWeight', 'bold', ...
                'ForegroundColor', th.sageDark);
            p1.Layout.Row = 1;
            p1.Layout.Column = 1;
            f1 = uigridlayout(p1, [12 2]);
            f1.RowHeight = [repmat({26}, 1, 11), {'1x'}];
            f1.ColumnWidth = {160, '1x'};
            f1.BackgroundColor = th.panel;
            c.SpansField = app.labeled(f1, 1, 'Span lengths [m]', uieditfield(f1, 'text', 'Value', '20', ...
                'Tooltip', 'One length per span, e.g. 20 20 for two equal spans'));
            c.ElementsField = app.labeled(f1, 2, 'Elements per span', uieditfield(f1, 'numeric', 'Value', 16, ...
                'Limits', [1 2000], 'RoundFractionalValues', 'on'));
            c.SupportsField = app.labeled(f1, 3, 'Supports at span ends', uieditfield(f1, 'text', 'Value', 'pin roller', ...
                'Tooltip', 'One per span end: pin, roller, fixed or none (e.g. pin roller roller)'));
            c.MaterialDropDown = app.labeled(f1, 4, 'Material', uidropdown(f1, 'Items', {'Steel', 'RCC'}, 'Value', 'Steel', ...
                'ValueChangedFcn', @(~, ~) app.onMaterialChanged()));
            c.EField = app.labeled(f1, 5, 'E [GPa]', uieditfield(f1, 'numeric', 'Value', 200, ...
                'Limits', [0 Inf], 'LowerLimitInclusive', 'off'));
            [c.IField, c.ILabel] = app.labeled(f1, 6, 'Is [m^4]', uieditfield(f1, 'numeric', 'Value', 0.01, ...
                'Limits', [0 Inf], 'LowerLimitInclusive', 'off'));
            c.MaterialNameField = app.labeled(f1, 7, 'Material name', uieditfield(f1, 'text', 'Value', ''));
            c.BasisField = app.labeled(f1, 8, 'Basis of E and I', uieditfield(f1, 'text', 'Value', '', ...
                'Tooltip', 'Where E and I (or Ieff) come from; kept with the results'));
            c.UDLField = app.labeled(f1, 9, 'Uniform load, down [kN/m]', uieditfield(f1, 'numeric', 'Value', 0, ...
                'Limits', [0 Inf]));
            c.NumbersCheckBox = uicheckbox(f1, 'Text', 'Show node and element numbers', 'Value', false, ...
                'ValueChangedFcn', @(~, ~) app.redrawAll());
            c.NumbersCheckBox.Layout.Row = 10;
            c.NumbersCheckBox.Layout.Column = [1 2];
            b = uibutton(f1, 'push', 'Text', 'Apply model', 'BackgroundColor', th.sage, ...
                'FontColor', th.buttonText, 'FontWeight', 'bold', 'ButtonPushedFcn', @(~, ~) app.applyModelInputs());
            b.Layout.Row = 11;
            b.Layout.Column = [1 2];
            note = uitextarea(f1, 'Editable', 'off', 'BackgroundColor', th.panel, 'FontColor', th.text, 'Value', { ...
                '2D equivalent Euler-Bernoulli beam (Option A): DOFs v and theta per node.'; ...
                'Steel: EI = Es*Is. RCC: EI = Ec*Ieff, with Ieff supplied by you and held constant (no cracking model).'; ...
                'Pin and roller both restrain v only in a bending-only model; fixed restrains v and theta.'; ...
                'Linear, quasi-static analysis. Not a load rating or design check.'});
            note.Layout.Row = 12;
            note.Layout.Column = [1 2];
            r1 = uigridlayout(g1, [2 1]);
            r1.Layout.Row = 1;
            r1.Layout.Column = 2;
            r1.RowHeight = {'1x', 150};
            r1.BackgroundColor = th.background;
            c.ModelAxes = uiaxes(r1);
            c.ModelAxes.Layout.Row = 1;
            c.ModelAxes.Layout.Column = 1;
            c.SummaryArea = uitextarea(r1, 'Editable', 'off', 'BackgroundColor', th.panel, 'FontColor', th.text);
            c.SummaryArea.Layout.Row = 2;
            c.SummaryArea.Layout.Column = 1;

            % ---- Tab 2: Vehicle and moving load
            t2 = uitab(tabs, 'Title', 'Vehicle & moving load', 'BackgroundColor', th.background);
            g2 = uigridlayout(t2, [1 2]);
            g2.ColumnWidth = {400, '1x'};
            g2.BackgroundColor = th.background;
            p2 = uipanel(g2, 'Title', 'Vehicle (quasi-static)', 'BackgroundColor', th.panel, 'FontWeight', 'bold', ...
                'ForegroundColor', th.sageDark);
            p2.Layout.Row = 1;
            p2.Layout.Column = 1;
            f2 = uigridlayout(p2, [9 2]);
            f2.RowHeight = [repmat({26}, 1, 7), {22, '1x'}];
            f2.ColumnWidth = {160, '1x'};
            f2.BackgroundColor = th.panel;
            c.AxleLoadsField = app.labeled(f2, 1, 'Axle loads, down [kN]', uieditfield(f2, 'text', 'Value', '80 120 120', ...
                'Tooltip', 'Front axle first'));
            c.SpacingsField = app.labeled(f2, 2, 'Axle spacings [m]', uieditfield(f2, 'text', 'Value', '4.2 1.4', ...
                'Tooltip', 'Between consecutive axles, front to rear'));
            c.VehicleNameField = app.labeled(f2, 3, 'Vehicle name', uieditfield(f2, 'text', ...
                'Value', 'Illustrative 3-axle truck'));
            c.StepField = app.labeled(f2, 4, 'Position step [m]', uieditfield(f2, 'numeric', 'Value', 0.1, ...
                'Limits', [0 Inf], 'LowerLimitInclusive', 'off'));
            c.DirectionDropDown = app.labeled(f2, 5, 'Travel direction', uidropdown(f2, 'Items', app.DirectionItems, ...
                'Value', app.DirectionItems{1}));
            c.MagnificationField = app.labeled(f2, 6, 'Deformation scale (0 = auto)', uieditfield(f2, 'numeric', ...
                'Value', 0, 'Limits', [0 Inf], 'ValueChangedFcn', @(~, ~) app.redrawAll()));
            b = uibutton(f2, 'push', 'Text', 'Apply vehicle', 'BackgroundColor', th.sage, ...
                'FontColor', th.buttonText, 'FontWeight', 'bold', 'ButtonPushedFcn', @(~, ~) app.applyVehicleInputs());
            b.Layout.Row = 7;
            b.Layout.Column = [1 2];
            lbl = uilabel(f2, 'Text', 'Support reactions at this position', 'FontWeight', 'bold', 'FontColor', th.sageDark);
            lbl.Layout.Row = 8;
            lbl.Layout.Column = [1 2];
            c.ReactionsTable = uitable(f2, 'Data', cell(0, 5), 'ColumnWidth', 'fit');
            c.ReactionsTable.Layout.Row = 9;
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
                'ValueChangingFcn', @(~, event) app.setVehiclePosition(event.Value), ...
                'ValueChangedFcn', @(src, ~) app.setVehiclePosition(src.Value));
            c.PositionSlider.Layout.Row = 1;
            c.PositionSlider.Layout.Column = 3;
            b = uibutton(s2, 'push', 'Text', 'Forward', 'ButtonPushedFcn', @(~, ~) app.stepVehicle(1));
            b.Layout.Row = 1;
            b.Layout.Column = 4;
            c.PositionLabel = uilabel(s2, 'Text', 'x_v = -', 'FontColor', th.text);
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
            r3 = uigridlayout(g3, [6 1]);
            r3.Layout.Row = [1 3];
            r3.Layout.Column = 2;
            r3.RowHeight = {34, 70, 22, '1x', 22, '1x'};
            r3.BackgroundColor = th.background;
            b = uibutton(r3, 'push', 'Text', 'Run moving-load analysis', 'BackgroundColor', th.sage, ...
                'FontColor', th.buttonText, 'FontWeight', 'bold', 'ButtonPushedFcn', @(~, ~) app.runEnvelopes());
            b.Layout.Row = 1;
            b.Layout.Column = 1;
            c.EnvelopeInfo = uitextarea(r3, 'Editable', 'off', 'BackgroundColor', th.panel, 'FontColor', th.text);
            c.EnvelopeInfo.Layout.Row = 2;
            c.EnvelopeInfo.Layout.Column = 1;
            lbl = uilabel(r3, 'Text', 'Critical vehicle positions (global extremes)', 'FontWeight', 'bold', ...
                'FontColor', th.sageDark);
            lbl.Layout.Row = 3;
            lbl.Layout.Column = 1;
            c.CriticalTable = uitable(r3, 'Data', cell(0, 7), 'ColumnWidth', 'fit');
            c.CriticalTable.Layout.Row = 4;
            c.CriticalTable.Layout.Column = 1;
            lbl = uilabel(r3, 'Text', 'Reaction envelopes', 'FontWeight', 'bold', 'FontColor', th.sageDark);
            lbl.Layout.Row = 5;
            lbl.Layout.Column = 1;
            c.EnvReactionsTable = uitable(r3, 'Data', cell(0, 7), 'ColumnWidth', 'fit');
            c.EnvReactionsTable.Layout.Row = 6;
            c.EnvReactionsTable.Layout.Column = 1;

            % ---- Tab: Damage (Stage 2)
            t6 = uitab(tabs, 'Title', 'Damage (Stage 2)', 'BackgroundColor', th.background);
            g6 = uigridlayout(t6, [1 2]);
            g6.ColumnWidth = {400, '1x'};
            g6.BackgroundColor = th.background;
            p6 = uipanel(g6, 'Title', 'Prescribed stiffness loss', 'BackgroundColor', th.panel, 'FontWeight', 'bold', ...
                'ForegroundColor', th.sageDark);
            p6.Layout.Row = 1;
            p6.Layout.Column = 1;
            f6 = uigridlayout(p6, [12 2]);
            f6.RowHeight = [repmat({26}, 1, 11), {'1x'}];
            f6.ColumnWidth = {170, '1x'};
            f6.BackgroundColor = th.panel;
            c.DamageFromField = app.labeled(f6, 1, 'Damaged region from x [m]', uieditfield(f6, 'numeric', 'Value', 7.5, ...
                'Tooltip', 'Must be a node coordinate'));
            c.DamageToField = app.labeled(f6, 2, 'Damaged region to x [m]', uieditfield(f6, 'numeric', 'Value', 12.5, ...
                'Tooltip', 'Must be a node coordinate, greater than "from"'));
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
            c.SupportNodeField = app.labeled(f6, 8, 'Support node (for Rmax)', uieditfield(f6, 'numeric', 'Value', 1, ...
                'Limits', [1 Inf], 'RoundFractionalValues', 'on'));
            c.SensitivityStepField = app.labeled(f6, 9, 'Sweep position step [m]', uieditfield(f6, 'numeric', 'Value', 0.5, ...
                'Limits', [0 Inf], 'LowerLimitInclusive', 'off'));
            b = uibutton(f6, 'push', 'Text', 'Run sensitivity', 'BackgroundColor', th.sage, 'FontColor', th.buttonText, ...
                'FontWeight', 'bold', 'ButtonPushedFcn', @(~, ~) app.runDamageSensitivity());
            b.Layout.Row = 10;
            b.Layout.Column = [1 2];
            c.DamageInfo = uitextarea(f6, 'Editable', 'off', 'BackgroundColor', th.panel, 'FontColor', th.text, ...
                'Value', {'No damage applied.'});
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
                {'Quantity', 'Healthy', 'Damaged', 'Change', 'Change [%]'}, 'ColumnWidth', 'fit');
            c.DamageTable.Layout.Row = [1 2];
            c.DamageTable.Layout.Column = 2;
            c.DamageFindings = uitextarea(gA, 'Editable', 'off', 'BackgroundColor', th.panel, 'FontColor', th.text, ...
                'FontSize', 13);
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
            c.SensitivityTable = uitable(gB, 'Data', cell(0, 6), 'ColumnName', ...
                {'Rank', 'Elements', 'x [m]', 'Value', 'Change', 'Change [%]'}, 'ColumnWidth', 'fit');
            c.SensitivityTable.Layout.Row = 1;
            c.SensitivityTable.Layout.Column = 2;

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
            c = app.Controls;
            if strcmp(c.MaterialDropDown.Value, 'RCC')
                c.ILabel.Text = 'Ieff [m^4]';
                if c.EField.Value == 200
                    c.EField.Value = 30;
                end
            else
                c.ILabel.Text = 'Is [m^4]';
                if c.EField.Value == 30
                    c.EField.Value = 200;
                end
            end
        end

        function xv = startPosition(app)
            if app.Direction > 0
                xv = app.PositionRange(1);
            else
                xv = app.PositionRange(2);
            end
        end

        function redrawAll(app)
            if ~isempty(app.Model)
                app.drawModelTab();
            end
            if ~isempty(app.PositionResult)
                app.drawPositionView();
            end
        end
    end
end
