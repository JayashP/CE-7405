function assertThrows(fcn, expectedId)
%ASSERTTHROWS Assert that calling FCN throws an error with identifier EXPECTEDID.
%   ASSERTTHROWS(FCN, EXPECTEDID) calls the function handle FCN with no
%   arguments. It prints the caught message if the expected error occurs,
%   and otherwise throws 'BridgeFE:test:noError' or 'BridgeFE:test:wrongError'.

threw = false;
actualId = '';
actualMessage = '';
try
    fcn();
catch err
    threw = true;
    actualId = err.identifier;
    actualMessage = err.message;
end

if ~threw
    error('BridgeFE:test:noError', 'Expected error "%s" but no error was thrown.', expectedId);
end
if ~strcmp(actualId, expectedId)
    error('BridgeFE:test:wrongError', 'Expected error "%s" but got "%s": %s', ...
        expectedId, actualId, actualMessage);
end
fprintf('  PASS expected error %s: %s\n', expectedId, actualMessage);
end
