function [ r ] = trainClassifiers( EEGtrain, EEGvalidation, classifiers, configs )
%TRAINCLASSIFIERS Trains classifiers with EEGtrain and EEGvalidation
%   For each classifier in the classifiers name list, trains the classifier
%   with the EEGtrain dataset and tests it with the EEGvalidation dataset.
%
%   Inputs:
%   EEGtrain        - EEG structure to train the classifiers
%   EEGvalidation   - EEG structure to train the classifiers
%   classifiers     - cell array with classifiers names or 'all'
%   configs         - Additional configurations for classifiers, if needed
    
    Train = prdataset(EEGtrain.features, EEGtrain.isTarget);
    Test = prdataset(EEGvalidation.features, EEGvalidation.isTarget);
    Train.prior = [(EEGtrain.nElements - 1)/EEGtrain.nElements  1 / EEGtrain.nElements];
    Test.prior = [(EEGvalidation.nElements - 1)/EEGvalidation.nElements  1 / EEGvalidation.nElements];
    
    
    EEGtrain.isTarget = double(EEGtrain.isTarget);
    EEGvalidation.isTarget = double(EEGvalidation.isTarget);
    
    r = struct();
    if cell2mat(intersect([{'svmp'} {'all'}], classifiers)) > 0
        best_metric = struct('accuracy', 0);
        best_model = [];
        for c = log10(logspace(0.01, 1, 10))
            tic;
            W =  svc(Train, proxm('p', 1), c);
            traint = toc;
            tic;
            V = Test * W;
            testt = toc;
            metrics = assessClassificationPerformance(EEGvalidation.isTarget, labeld(V), V.data(:,2), EEGvalidation.nElements);
            metrics.C = c;
            if metrics.accuracy > best_metric.accuracy
                best_metric = metrics;
                best_model = W;
                best_traint = traint;
                best_testt = testt;
            end
        end
        r.svmp = struct('model', best_model, 'metrics', best_metric, 'traint', best_traint, 'testt', best_testt);
    end
    
    
    
    if cell2mat(intersect([{'svm'} {'all'}], classifiers)) > 0
        best_metric = struct('accuracy', 0);
        best_model = [];
        for c = log10(logspace(0.01, 1, 10))
            tic;
            svm = fitcsvm(Train.data, Train.labels, 'BoxConstraint', c);
            traint = toc;
            tic;
            [labels, scores] = svm.predict(Test.data);
            testt = toc;
            metrics = assessClassificationPerformance(EEGvalidation.isTarget, double(labels), scores(:,2), EEGvalidation.nElements);
            metrics.C = c;
            if metrics.accuracy > best_metric.accuracy
                best_metric = metrics;
                best_model = svm;
                best_traint = traint;
                best_testt = testt;
            end
        end
        r.svm = struct('model', best_model, 'metrics', best_metric, 'traint', best_traint, 'testt', best_testt);

    end
    
    
    if cell2mat(intersect([{'svmh'} {'all'}], classifiers)) > 0
       W = svc(Train, 'h');
       V = Test * W;
       
       metrics = assessClassificationPerformance(EEGvalidation.isTarget, labeld(V), V.data(:,2), EEGvalidation.nElements);
       r.svmh = struct('model', W, 'metrics', metrics);
    end
    
    
    
    if cell2mat(intersect([{'fisher'} {'all'}], classifiers)) > 0
       tic;
       W =  fisherc(Train);
       traint = toc;
       tic;
       V = Test * W;
       testt = toc;
       
       metrics = assessClassificationPerformance(EEGvalidation.isTarget, labeld(V), V.data(:,2), EEGvalidation.nElements);
       r.fisher = struct('model', W, 'metrics', metrics, 'traint', traint, 'testt', testt);       
    end
    
    if cell2mat(intersect([{'klld'} {'all'}], classifiers)) > 0
       W =  klldc(Train);
       V = Test * W;
       
       metrics = assessClassificationPerformance(EEGvalidation.isTarget, labeld(V), V.data(:,2), EEGvalidation.nElements);
       r.klld = struct('model', W, 'metrics', metrics);
    end
    
    if cell2mat(intersect([{'pcld'} {'nall'}], classifiers)) > 0
       W =  pcldc(Train);
       V = Test * W;
       
       metrics = assessClassificationPerformance(EEGvalidation.isTarget, labeld(V), V.data(:,2), EEGvalidation.nElements);
       r.pcld = struct('model', W, 'metrics', metrics);
       
    end
    
    if cell2mat(intersect([{'logl'} {'all'}], classifiers)) > 0
       W =  loglc(Train);
       V = Test * W;
       
       metrics = assessClassificationPerformance(EEGvalidation.isTarget, labeld(V), V.data(:,2), EEGvalidation.nElements);
       r.loglc = struct('model', W, 'metrics', metrics);
       
    end

    if cell2mat(intersect([{'nm'} {'all'}], classifiers)) > 0
       W =  nmc(Train);
       V = Test * W;
       
       metrics = assessClassificationPerformance(EEGvalidation.isTarget, labeld(V), V.data(:,2), EEGvalidation.nElements);
       r.nm = struct('model', W, 'metrics', metrics);       
    end

    if cell2mat(intersect([{'nms'} {'all'}], classifiers)) > 0
       W =  nmsc(Train);
       V = Test * W;
       
       metrics = assessClassificationPerformance(EEGvalidation.isTarget, labeld(V), V.data(:,2), EEGvalidation.nElements);
       r.nms = struct('model', W, 'metrics', metrics);       
    end

    if cell2mat(intersect([{'perl'} {'all'}], classifiers)) > 0
       W =  perlc(Train);
       V = Test * W;
       
       metrics = assessClassificationPerformance(EEGvalidation.isTarget, labeld(V), V.data(:,2), EEGvalidation.nElements);
       r.perl = struct('model', W, 'metrics', metrics);
       
    end
    
    if cell2mat(intersect([{'quadr'} {'all'}], classifiers)) > 0
       W =  quadrc(Train);
       V = Test * W;
       
       metrics = assessClassificationPerformance(EEGvalidation.isTarget, labeld(V), V.data(:,2), EEGvalidation.nElements);
       r.quadr = struct('model', W, 'metrics', metrics);
       
    end

    
    if cell2mat(intersect([{'ld'} {'all'}], classifiers)) > 0
       W =  ldc(Train);
       V = Test * W;
       
       metrics = assessClassificationPerformance(EEGvalidation.isTarget, labeld(V), V.data(:,2), EEGvalidation.nElements);
       r.ld = struct('model', W, 'metrics', metrics);
       
    end
    
    if cell2mat(intersect([{'qd'} {'all'}], classifiers)) > 0
       W =  qdc(Train);
       V = Test * W;
       
       metrics = assessClassificationPerformance(EEGvalidation.isTarget, labeld(V), V.data(:,2), EEGvalidation.nElements);
       r.qd = struct('model', W, 'metrics', metrics);
       
    end
    
    if cell2mat(intersect([{'ud'} {'all'}], classifiers)) > 0
       W =  udc(Train);
       V = Test * W;
       
       metrics = assessClassificationPerformance(EEGvalidation.isTarget, labeld(V), V.data(:,2), EEGvalidation.nElements);
       r.ud = struct('model', W, 'metrics', metrics);
       
    end
    
    if cell2mat(intersect([{'nbc'} {'all'}], classifiers)) > 0
       tic;
       nbc = fitcnb(EEGtrain.features, EEGtrain.isTarget);
       traint = toc;
       tic;
       [labels, predictionProbabilities, ~] = nbc.predict(EEGvalidation.features);
       testt = toc;
       
       metrics = assessClassificationPerformance(EEGvalidation.isTarget, labels, predictionProbabilities(:, 2), EEGvalidation.nElements);
       r.nbc = struct('model', nbc, 'metrics', metrics, 'traint', traint, 'testt', testt);
       
    end
    
    
    if cell2mat(intersect([{'naiveb'} {'all'}], classifiers)) > 0
       tic;
       W = naivebc(Train);
       traint = toc;
       tic;
       V = Test * W;
       testt = toc;
       
       metrics = assessClassificationPerformance(EEGvalidation.isTarget, labeld(V), V.data(:,2), EEGvalidation.nElements);
       r.naiveb = struct('model', W, 'metrics', metrics, 'traint', traint, 'testt', testt);
       
    end
    
    if cell2mat(intersect([{'parzen'} {'all'}], classifiers)) > 0
       W = parzenc(Train);
       V = Test * W;
       
       metrics = assessClassificationPerformance(EEGvalidation.isTarget, labeld(V), V.data(:,2), EEGvalidation.nElements);
       r.parzen = struct('model', W, 'metrics', metrics);
       
    end
    
    if cell2mat(intersect([{'parzend'} {'all'}], classifiers)) > 0
       W = parzendc(Train);
       V = Test * W;
       
       metrics = assessClassificationPerformance(EEGvalidation.isTarget, labeld(V), V.data(:,2), EEGvalidation.nElements);
       r.parzend = struct('model', W, 'metrics', metrics);
       
    end
    
    
    if cell2mat(intersect([{'tree'} {'all'}], classifiers)) > 0
      try
       W = treec(Train);
       V = Test * W;
       
       metrics = assessClassificationPerformance(EEGvalidation.isTarget, labeld(V), V.data(:,2), EEGvalidation.nElements);
       r.tree = struct('model', W, 'metrics', metrics);
       
      catch
          r.tree = struct('model', nan, 'metrics', nan);
      end
    end
    
    if cell2mat(intersect([{'knn'} {'all'}], classifiers)) > 0
       W =  knnc(Train, 5);
       V = Test * W;
       
       metrics = assessClassificationPerformance(EEGvalidation.isTarget, labeld(V), V.data(:,2), EEGvalidation.nElements);
       r.knn = struct('model', W, 'metrics', metrics);
       
    end
    
    
%     if cell2mat(intersect([{'neur'} {'all'}], classifiers)) > 0
%        W = neurc(Train);
%        V = Test * W;
%        
%        cm = confmat(getlabels(Test), labeld(V));
%        
%        cfm = zeros(2);
%        cfm(cm~=0) = cm(cm~=0);
%        
%        r.neur = getResults(cfm, 'neur', 1);       
%        
%     end
%     
    
%     if cell2mat(intersect([{'bpxn'} {'all'}], classifiers)) > 0
%        W = bpxnc(Train);
%        V = Test * W;
%        
%        cm = confmat(getlabels(Test), labeld(V));
%        
%        cfm = zeros(2);
%        cfm(cm~=0) = cm(cm~=0);
%        
%        r.bpxn = getResults(cfm, 'bpxn', 1);       
%        
%     end
    
%     if cell2mat(intersect([{'rnn'} {'all'}], classifiers)) > 0
%        W = rnnc(Train);
%        V = Test * W;
%        
%        cm = confmat(getlabels(Test), labeld(V));
%        
%        cfm = zeros(2);
%        cfm(cm~=0) = cm(cm~=0);
%        
%        r.rnn = getResults(cfm, 'rnn', 1);       
%        
%     end
    

    if cell2mat(intersect([{'wisard'} {'all'}], classifiers)) > 0
        best_metric = struct('accuracy', 0);
        best_model = [];
        
       for nlevels = configs.WISARD.nlevels
           tic;
           [featTrain, levels] = WiSARD.binarizeData(Train.data, 'thermometer', nlevels);
           binarizationtraintime = toc;
           tic;
           featTest = WiSARD.binarizeData(Test.data, 'thermometer', nlevels, levels);
           binarizationtesttime = toc;
           for nbits = configs.WISARD.nbits
               W = WiSARD(num2cell([0 1]), size(featTrain, 2), nbits, [], [], Train.prior);
               tic;
               W.fit(featTrain, num2cell(Train.labels));
               traint = toc;
               W.misc.levels = levels;
               
               model_to_save = W;
               
               % with zeros
               [~, ~, counts] = W.predict(featTest);
               for threshold = configs.WISARD.thresholds 
                   if threshold > 0.001
                       model_to_save = [];
                   end
                   tic;
                   [labels, scores] = W.bleach(counts, threshold);
                   scores = scores(:, 2) - scores(:, 1);
                   testt = toc;
                   metrics = assessClassificationPerformance(EEGvalidation.isTarget, cell2mat(labels), scores, EEGvalidation.nElements);
                   metrics.nbits = nbits; metrics.nlevels = nlevels; metrics.threshold = threshold;
                   if metrics.accuracy > best_metric.accuracy
                       best_metric = metrics;
                       best_model = W;
                       best_binarizationtraintime = binarizationtraintime;
                       best_binarizationtesttime = binarizationtesttime;
                       best_traint = traint;
                       best_testt = testt;
                   end
                   
                   r.(sprintf('wisard_nb_%d_nl_%d_th_%d', nbits, nlevels, floor(threshold*100))) = struct('model', model_to_save, 'metrics', metrics,  ...
                       'binarizationtraintime', binarizationtraintime, 'binarizationtesttime', binarizationtesttime, ...
                       'traint', traint, 'testt', testt);
               end
               
               continue;
               % without zeros
               W_nozeros = W.clone();
               W_nozeros.cleanZeros();
               model_to_save = W_nozeros;
               [~, ~, counts] = W_nozeros.predict(featTest);
               for threshold = configs.WISARD.thresholds 
                   if threshold > 0.001
                       model_to_save = [];
                   end
                   [labels, scores] = W_nozeros.bleach(counts, threshold);
                   scores = scores(:, 2) - scores(:, 1);
                   metrics = assessClassificationPerformance(EEGvalidation.isTarget, cell2mat(labels), scores, EEGvalidation.nElements);
                   r.(sprintf('wisard_nb_%d_nl_%d_th_%d_nozeros', nbits, nlevels, floor(threshold*100))) = struct('model', model_to_save, 'metrics', metrics);
               end
           end
       end
       
       r.best_wisard = struct('model', best_model, 'metrics', best_metric, ...
           'metricsbinarizationtraintime',best_binarizationtraintime, ...
           'metricsbinarizationtesttime', best_binarizationtesttime, ...
           'traint', best_traint, 'testt', best_testt);
       
    end



end

