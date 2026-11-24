function [message, identifier] = errorMessage(fcn)
%ERRORMESSAGE Message and identifier of the error FCN throws ('' and '' if it throws none).
%   [MESSAGE, IDENTIFIER] = ERRORMESSAGE(FCN) calls the function handle FCN
%   with no arguments. Tests use it to check the exact wording of a message
%   (ASSERTTHROWS checks the identifier only).
%
%   See also ASSERTTHROWS.
message = '';
identifier = '';
try
    fcn();
catch err
    message = err.message;
    identifier = err.identifier;
end
end
