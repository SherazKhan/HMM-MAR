function [options,data] = checkoptions (options,data,T,cv)

if nargin<4, cv = 0; end
if isempty(strfind(which('pca'),matlabroot))
    error(['Function pca() seems to be other than Matlab''s own - you need to rmpath() it. ' ...
        'Use ''rmpath(fileparts(which(''pca'')))'''])
end

if ~isfield(options,'K'), error('K was not specified'); end
if options.K<1, error('K must be higher than 0'); end
if ~isstruct(data), data = struct('X',data); end
if size(data.X,1)~=sum(T)
    error('Total time specified in T does not match the size of the data')
end

% data options
if ~isfield(options,'Fs'), options.Fs = 1; end
if ~isfield(options,'onpower'), options.onpower = 0; end
if ~isfield(options,'embeddedlags'), options.embeddedlags = 0; end
if ~isfield(options,'pca'), options.pca = 0; end
if ~isfield(options,'varimax'), options.varimax = 0; end
if ~isfield(options,'pcamar'), options.pcamar = 0; end
if ~isfield(options,'pcapred'), options.pcapred = 0; end
if ~isfield(options,'vcomp') && options.pcapred>0, options.vcomp = 1; end
if ~isfield(options,'filter'), options.filter = []; end
if ~isfield(options,'detrend'), options.detrend = 0; end
if ~isfield(options,'downsample'), options.downsample = 0; end
if ~isfield(options,'standardise'), options.standardise = 1; end
if ~isfield(options,'standardise_pc'), options.standardise_pc = 0; end

if ~isempty(options.filter)
    if length(options.filter)~=2, error('options.filter must contain 2 numbers of being empty'); end
    if (options.filter(1)==0 && isinf(options.filter(2)))
        warning('The specified filter does not do anything - Ignoring.')
        options.filter = [];
    elseif (options.filter(2) < options.Fs/2) && options.order >= 1
        warning(['The lowpass cutoff frequency is lower than the Nyquist frequency - ' ...
            'This is discouraged for a MAR model'])
    end
end

if options.downsample > 0 && isfield(data,'C')
    warning('The use of downsampling is currently not compatible with specifying data.C');
    data = rmfield(data,'C');
end

if length(options.pca)==1 && options.pca == 0
    ndim = length(options.embeddedlags) * size(data.X,2);
elseif options.pca(1) < 1
    ndim = size(data.X,2); % temporal assignment
else
    ndim = options.pca;
end
if ~isfield(options,'S') 
    if options.pcamar>0, options.S = ones(options.pcamar,ndim);
    else options.S = ones(ndim); 
    end
elseif (size(data.X,2)~=size(options.S,1)) || (size(data.X,2)~=size(options.S,2))
    error('Dimensions of S are incorrect; must be a square matrix of size nchannels by nchannels')
end

options = checkMARparametrization(options,[],ndim); copyopt = options;

% if options.crosstermsonly
%     options.covtype = 'uniquediag';
%     options.S = - ones(2*ndim);
%     options.S(1:ndim,1:ndim) = ones(ndim) - 2*eye(ndim);
%     options.order = 1; 
%     options.zeromean = 1; 
% end

options.multipleConf = isfield(options,'state');
if options.multipleConf && options.pcamar>0
    error('Multiple configurations are not compatible with pcamar>0');
end
if options.multipleConf && options.pcapred>0
    error('Multiple configurations are not compatible with pcapred>0');
end
if options.multipleConf && length(options.embeddedlags)>1 
    error('Multiple configurations are not compatible with embeddedlags');
end
% if options.multipleConf && options.crosstermsonly 
%     error('Multiple configurations are not compatible with crosstermsonly')
% end
if options.pcamar>0 && options.pcapred>0
    error('Options pcamar and pcapred are not compatible')
end


if options.multipleConf
    options.maxorder = 0;
else
    [options.orders,options.maxorder] = ...
        formorders(options.order,options.orderoffset,options.timelag,options.exptimelag);
end

if ~isfield(options,'state') || isempty(options.state)
    for k = 1:options.K
        options.state(k) = struct();
    end
end
for k = 1:options.K
    if isfield(options.state(k),'train') && ~isempty(options.state(k).train)
        options.state(k).train = checkMARparametrization(options.state(k).train,options.S,ndim);
    else
        options.state(k).train = copyopt;
    end
    train =  options.state(k).train;
    [options.state(k).train.orders,order] = ...
        formorders(train.order,train.orderoffset,train.timelag,train.exptimelag);
    options.maxorder = max(options.maxorder,order);
end

data = data2struct(data,T,options);

% training options
if ~isfield(options,'cyc'), options.cyc = 1000; end
if ~isfield(options,'tol'), options.tol = 1e-5; end
if ~isfield(options,'meancycstop'), options.meancycstop = 1; end
if ~isfield(options,'cycstogoafterevent'), options.cycstogoafterevent = 20; end
if ~isfield(options,'initTestSmallerK'), options.initTestSmallerK = false; end 
% For hmmmar init type, if initTestSmallerK is true, initializations with smaller 
% K will be tested up to specified K. See hmmmar_init.m
if ~isfield(options,'initcyc'), options.initcyc = 100; end
if ~isfield(options,'initrep'), options.initrep = 4; end
if ~isfield(options,'inittype'), options.inittype = 'hmmmar'; end 
if ~isfield(options,'Gamma'), options.Gamma = []; end
if ~isfield(options,'hmm'), options.hmm = []; end
if ~isfield(options,'fehist'), options.fehist = []; end
if ~isfield(options,'DirichletDiag'), options.DirichletDiag = 10; end
if ~isfield(options,'PriorWeighting'), options.PriorWeighting = 1; end
if ~isfield(options,'dropstates'), options.dropstates = 1; end
%if ~isfield(options,'whitening'), options.whitening = 0; end
if ~isfield(options,'repetitions'), options.repetitions = 1; end
if ~isfield(options,'updateObs'), options.updateObs = 1; end
if ~isfield(options,'updateGamma'), options.updateGamma = 1; end
if ~isfield(options,'decodeGamma'), options.decodeGamma = 1; end
if ~isfield(options,'keepS_W'), options.keepS_W = 1; end
if ~isfield(options,'useParallel')
    options.useParallel = (length(T)>1);
end

%if ~options.updateObs && ~isfield(options.state,'W') 
%    error('If updateObs is 0, you need to specify the parameters of the states in options.state')
%end

if ~isfield(options,'useMEX') || options.useMEX==1
    options.useMEX = verifyMEX(); 
end

if ~isfield(options,'verbose'), options.verbose = 1; end

if options.maxorder+1 >= min(T)
   error('There is at least one trial that is too short for the specified order') 
end

% if isempty(options.Gamma) && ~isempty(options.hmm)
%     error('Gamma must be provided in options if you want a warm restart')
% end

if ~strcmp(options.inittype,'random') && options.initrep == 0
    options.inittype = 'random';
    warning('Non random init was set, but initrep==0')
end

if options.K~=size(data.C,2), error('Matrix data.C should have K columns'); end
if options.K>1 && options.updateGamma == 0 && isempty(options.Gamma)
    warning('Gamma is unspecified, so updateGamma was set to 1');  options.updateGamma = 1; 
end
if options.updateGamma == 1 && options.K == 1
    warning('Since K is one, updateGamma was set to 0');  options.updateGamma = 0; 
end
if options.updateGamma == 0 && options.repetitions>1
    error('If Gamma is not going to be updated, repetitions>1 is unnecessary')
end

if ~isempty(options.Gamma)
    if length(options.embeddedlags)>1
        if (size(options.Gamma,1) ~= (sum(T) - length(options.embeddedlags) + 1 )) || ...
                (size(options.Gamma,2) ~= options.K)
            error('The supplied Gamma has not the right dimensions')
        end        
    else
        if (size(options.Gamma,1) ~= (sum(T) - options.maxorder*length(T))) || ...
                (size(options.Gamma,2) ~= options.K)
            error('The supplied Gamma has not the right dimensions')
        end
    end
end

if (length(T) == 1 && options.initrep==1) && options.useParallel == 1
    warning('Only one trial, no use for parallel computing')
    options.useParallel = 0;
end

if cv==1
    if ~isfield(options,'cvfolds'), options.cvfolds = length(T); end
    if ~isfield(options,'cvrep'), options.cvrep = 1; end
    if ~isfield(options,'cvmode'), options.cvmode = 1; end
    if ~isfield(options,'cvverbose'), options.cvverbose = 0; end
    if length(options.cvfolds)>1 && length(options.cvfolds)~=length(T), error('Incorrect assigment of trials to folds'); end
    if length(options.cvfolds)>1 && ~isempty(options.Gamma), error('Set options.Gamma=[] for cross-validating'); end
    if length(options.cvfolds)==1 && options.cvfolds==0, error('Set options.cvfolds to a positive integer'); end
    if options.K==1 && isfield(options,'cvrep')>1, warning('If K==1, cvrep>1 has no point; cvrep is set to 1 \n'); end
end

end


function options = checkMARparametrization(options,S,ndim)

if ~isfield(options,'order')
    options.order = 0;
    warning('order was not specified - it will be set to 0'); 
end
if isfield(options,'embeddedlags') && length(options.embeddedlags)>1 && options.order>0 
    error('Order needs to be zero for multiple embedded lags')
end
if isfield(options,'AR') && options.AR == 1
    if options.order == 0, error('Option AR cannot be 1 if order==0'); end
   %if isfield(options,'S'), 
   %    warning('Because you specified AR=1, S will be overwritten')
   %end
   options.S = -1*ones(ndim) + 2*eye(ndim);  
end

if isfield(options,'pcamar') && options.pcamar>0 
    if options.order==0, error('Option pcamar>0 must be used with some order>0'); end
    if isfield(options,'S') && any(options.S(:)~=1), error('S must have all elements equal to 1 if pcamar>0'); end 
    if isfield(options,'symmetricprior') && options.symmetricprior==1, error('Priors must be symmetric if pcamar>0'); end
    if isfield(options,'uniqueAR') && options.uniqueAR==1, error('pcamar cannot be >0 if uniqueAR is set to 0'); end
end
if isfield(options,'pcapred') && options.pcapred>0 
    if options.order==0, error('Option pcapred>0 must be used with some order>0'); end
    if isfield(options,'S') && any(options.S(:)~=1), error('S must have all elements equal to 1 if pcapred>0'); end 
    if isfield(options,'symmetricprior') && options.symmetricprior==1
        error('Option symmetricprior makes no sense if pcamar>0'); 
    end
    if isfield(options,'uniqueAR') && options.uniqueAR==1, error('pcapred cannot be >0 if uniqueAR is set to 0'); end
end
if ~isfield(options,'covtype') && ndim==1, options.covtype = 'diag'; 
elseif ~isfield(options,'covtype') && ndim>1, options.covtype = 'full'; 
elseif (strcmp(options.covtype,'full') || strcmp(options.covtype,'uniquefull')) && ndim==1
    warning('Covariance can only be diag or uniquediag if data has only one channel')
    if strcmp(options.covtype,'full'), options.covtype = 'diag';
    else options.covtype = 'uniquediag';
    end
end
if ~isfield(options,'zeromean')
    if options.order>0, options.zeromean = 1; 
    else options.zeromean = 0;
    end
end
if ~isfield(options,'timelag'), options.timelag = 1; end
if ~isfield(options,'exptimelag'), options.exptimelag = 1; end
if ~isfield(options,'orderoffset'), options.orderoffset = 0; end
if ~isfield(options,'symmetricprior'),  options.symmetricprior = 0; end
if ~isfield(options,'uniqueAR'), options.uniqueAR = 0; end
%if ~isfield(options,'crosstermsonly'), options.crosstermsonly = 0; end

if (options.order>0) && (options.order <= options.orderoffset)
    error('order has to be either zero or higher than orderoffset')
end
if (options.order>0) && (options.timelag<1) && (options.exptimelag<=1)
    error('if order>0 then you should specify either timelag>=1 or exptimelag>=1')
end
if ~isfield(options,'S')
    if nargin>=2 && ~isempty(S)
        if (length(options.pca)==1 && options.pca==0) || all(S(:))==1
            options.S = S;
        else
            warning('S cannot have elements different from 1 if PCA is going to be used')
            options.S = ones(size(S));
        end
    else
        options.S = ones(ndim);
    end
elseif nargin>=2 && ~isempty(S) && any(S(:)~=options.S(:))
    error('S has to be equal across states')
end
if options.uniqueAR==1 && any(S(:)~=1)
    warning('S has no effect if uniqueAR=1')
end
if (strcmp(options.covtype,'full') || strcmp(options.covtype,'uniquefull')) && any(S(:)~=1)
   error('Using S with elements different from zero is only implemented for covtype=diag/uniquediag')
end

orders = formorders(options.order,options.orderoffset,options.timelag,options.exptimelag);
if ~isfield(options,'prior') || isempty(options.prior)
    options.prior = [];
elseif ~options.uniqueAR && ndim>1
    error('Fixed priors are only implemented for uniqueAR==1 (or just one channel)')
elseif ~isfield(options.prior,'S') || ~isfield(options.prior,'Mu')
    error('You need to specify S and Mu to set a prior on W')
elseif size(options.prior.S,1)~=(length(orders) + ~options.zeromean) ...
        || size(options.prior.S,2)~=(length(orders) + ~options.zeromean)
    error('The covariance matrix of the supplied prior has not the right dimensions')
elseif cond(options.prior.S) > 1/eps
    error('The covariance matrix of the supplied prior is ill-conditioned')
elseif size(options.prior.Mu,1)~=(length(orders) + ~options.zeromean) || size(options.prior.Mu,2)~=1
    error('The mean of the supplied prior has not the right dimensions')
else
    options.prior.iS = inv(options.prior.S);
    options.prior.iSMu = options.prior.iS * options.prior.Mu;
end
if ~issymmetric(options.S) && options.symmetricprior==1
   error('In order to use a symmetric prior, you need S to be symmetric as well') 
end
if (strcmp(options.covtype,'full') || strcmp(options.covtype,'uniquefull')) &&  ~all(options.S(:)==1)
    error('if S is not all set to 1, then covtype must be diag or uniquediag')
end
if (strcmp(options.covtype,'full') || strcmp(options.covtype,'uniquefull')) && options.uniqueAR
    error('covtype must be diag or uniquediag if uniqueAR==1')
end
if options.uniqueAR && ~options.zeromean
    error('When unique==1, modelling the mean is not yet supported')
end
if (strcmp(options.covtype,'uniquediag') || strcmp(options.covtype,'uniquefull')) && ...
        options.order == 0 && options.zeromean == 1
   error('Unique covariance matrix, order=0 and no mean modelling: there is nothing left to drive the states..') 
end

if options.pcapred>0
    options.Sind = ones(options.pcapred,ndim);
else
    options.Sind = formindexes(orders,options.S);
end
if ~options.zeromean, options.Sind = [true(1,ndim); options.Sind]; end
end


function test = issymmetric(A)

B = A';
test = all(A(:)==B(:)); 
end

function isfine = verifyMEX()
isfine = 1;
try
    [~,~,~]=hidden_state_inference_mx(1,1,1,0);
catch
    isfine = 0;
end
end
