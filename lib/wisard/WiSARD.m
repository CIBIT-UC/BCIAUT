classdef WiSARD < handle
%WISARD Wilkie,Stonham & Aleksander�s Recognition Device matlab implementation
%   WiSARD algorithm matlab implementation. It comprises both matrix
%   (direct access - fast but requires huge ammount of memory) and map
%   (hashmap access - slower but requires small amount of memory)
%
%   Creator Marco Simoes (msimoes@dei.uc.pt) 2017
%   All rights reserved


    properties
        discriminators  % cell array of discriminators (one per class)
        classes         % cell array of classes identifiers
        nmemories       % number of memories per discriminator
        nbits           % number of bits per memory
        bits_order      % random mapping of inputs to memories
        use_map         % boolean for using map (1) or matrix (0)
        priors          % array of prior class probability
        max_threshold   % higher threshold value for predictive bleaching
        misc            % help structure for additional model variables
    end
    
    methods      
        function obj = WiSARD(classes, input_size, nbits, bits_order, use_map, priors, max_threshold)
            % Constructor creates base parameters for the classifier
            %
            % Input:
            % classes       -  class identifiers in a cell array, ex. {0 1}
            % input_size    -  length of each sample (feature vector)
            % nbits         -  number of bits to use on each memory
            % bits_order    -  random mapping of bits to memories
            % use_map       -  boolean for using map or matrix in discriminators
            % priors        -  class relative frequencies
            % max_threshold -  higher threshold value for predictive bleaching 
            if nargin < 3
                error('Not enough input arguments');
            end
            if nargin < 4 || isempty(bits_order)
                rng(1); % seed for reproduceability
                bits_order = randperm(input_size);
            end
            if nargin < 5 || isempty(use_map)
                % automatically choose between map or matrix based on
                % input_size and nbits
                use_map = (2^nbits * (input_size / nbits) * length(classes)) > 1E7;
            end
            if nargin < 6
                % if no priors provided, leave empty and will compute from
                % training set
                priors = [];
            end
            if nargin < 7
                max_threshold = 0.5;
            end
            
            % map input parameters to class
            obj.classes = classes;
            obj.nbits = nbits;
            obj.nmemories = ceil(input_size / nbits);
            obj.use_map = use_map;
            obj.bits_order = bits_order;            
            obj.priors = priors;
            obj.max_threshold = max_threshold;
            obj.misc = struct();
            
            
            % create discriminators
            for c = 1:length(classes)
                if obj.use_map == 1
                    % create an array of maps (one per memory)
                    obj.discriminators{c} = cell(1, obj.nmemories);
                    for m = 1:obj.nmemories
                        obj.discriminators{c}{m} = containers.Map('KeyType','uint32','ValueType','double');
                    end
                else
                    % create a sparse matrix by discriminator, each line 
                    % corresponds to a memory
                    obj.discriminators{c} = zeros(obj.nmemories, 2^obj.nbits);
                end
            end
            
        end

        
        function [w] = clone(obj)
            w = WiSARD(obj.classes, length(obj.bits_order), obj.nbits, obj.bits_order, obj.use_map, obj.priors, obj.max_threshold);
            w.misc = obj.misc;
            
            for d = 1:length(w.classes)
                w.discriminators{d} = obj.discriminators{d};
            end

        end
        
        
        function fit(obj, data, labels)
            % Trains the classifier with data and respective labels
            
            % apply reordering of bits
            data = obj.shuffleData( data );
            
            % transform bit streams into memory addresses
            dataAddr = obj.bin2Addr( data );
            
            % enforce labels to be cell array
            if ~iscell(labels) 
                labels = num2cell(labels);
            end
            
            % compute priors if not defined
            if isempty(obj.priors)
                obj.priors = hist(cell2mat(labels), length(unique(cell2mat(labels))))/length(labels);
            end
            
            % transform labels to class indexes
            classIdxs = nan(size(labels));
            for i=1:length(labels)
                classIdxs(i) = find([obj.classes{:}] == cell2mat(labels(i)));
            end
            
            
            % call respective training function: map or matrix
            if obj.use_map == 1
                obj.fitMap(dataAddr, classIdxs);
            else
                obj.fitMatrix(dataAddr, classIdxs);
            end
            
            
        end
        
        function fitMap(obj, dataAddr, classIdxs)
            % Trains the WiSARD using the map discriminators
            
            nSamples = size(dataAddr, 1);
            for i = 1:nSamples
                for m = 1:obj.nmemories
                    % get memory address
                    addr = dataAddr(i, m);
                    
                    % increase memory address with 1/nSamples of its class
                    value = WiSARD.mapGet(obj.discriminators{classIdxs(i)}{m}, addr) + 1 / (obj.priors(classIdxs(i)) * nSamples);
                    obj.discriminators{classIdxs(i)}{m}(addr) = value;
                end
            end
        end
        
        
        function fitMatrix(obj, dataAddr, classIdxs)
            % Trains the WiSARD using the matrix discriminators
            
            nSamples = size(dataAddr, 1);
            for i = 1:nSamples
                % get memory addresses
                idxs = dataAddr(i, :) * obj.nmemories + (1:obj.nmemories);
                
                % increase memory addresses with 1/nSamples of its class
                values = obj.discriminators{classIdxs(i)}(idxs) + 1 / (obj.priors(classIdxs(i)) * nSamples);
                obj.discriminators{classIdxs(i)}(idxs) = values;
            end            
        end
        
        
        function cleanZeros(obj)
            % Sets zero counts (first address of each memory) to 0
            
            for c = 1:length(obj.classes)
                if obj.use_map == 0
                    obj.discriminators{c}(:, 1) = 0;
                else
                    for m = 1:obj.nmemories
                        obj.discriminators{c}{m}(0) = 0;
                    end
                end
            end
        end
        
        function [labels, classCounts, rawCounts] = predict(obj, data)
            % Performs label prediction of input data
            
            % shuffles data and transforms to addresses
            dataAddr = obj.bin2Addr( obj.shuffleData( data ) );
            
            % calls respective prediction methods (map or matrix)
            if obj.use_map == 1
                rawCounts = obj.predictMap(dataAddr);
            else
                rawCounts = obj.predictMatrix(dataAddr);
            end
            
            [labels, classCounts] = obj.bleach(rawCounts, obj.max_threshold);
            
        end
        
        function [labels, classCounts] = bleach(obj, rawCounts, maxThreshold)
            % Bleach the memory counts. Uses 100 thresholds from 0 to
            % maxThreshold to count how many memories are above threashold
            % for each of those and computes confidence values for each.
            % Returns the count with bigger confidence for each sample.
            if nargin < 3
                maxThreshold = obj.max_threshold;
            end
            
            % results are of type [nSamples, nClasses, nMemories]
            [nSamples, nClasses, nMemories] = size(rawCounts);
                        
            NTHRESHOLDS = 100;
            
            thresholds = nan(1,1,NTHRESHOLDS);            
            % thresholds go from ~0 to max_threshold
            thresholds(1,1,1:NTHRESHOLDS) = (1:NTHRESHOLDS) * maxThreshold ./ NTHRESHOLDS;
            thresholds = repmat(thresholds, [nClasses nMemories 1]);
            
            
            % initialize confidence array
            classCounts = nan(nSamples, nClasses);
            
            for i = 1:size(rawCounts, 1)
                % get total values for each sample in each discriminant and each memory
                % repeat it NTHRESHOLD times ([nClasses, nMemories, NTHRESHOLDS])
                sampleData = repmat(squeeze(rawCounts(i, :, :)), 1,1,NTHRESHOLDS);
                
                % threshold data
                sampleData = sampleData > thresholds;
            
                % make counts for each class and for each threshold level
                sampleActivatedMemoriesCount = squeeze(sum(sampleData, 2));
                
                % confidence for each threshold is the difference between
                % the highest and second highest class counts
                sortedCounts = sort(sampleActivatedMemoriesCount, 'descend');
                confidence = squeeze(sortedCounts(1, :) - sortedCounts(2, :) ) ./ obj.nmemories;
                
                % find best confidence
                [~, maxConfidenceIdx] = max(confidence);
                classCounts(i, :) = sampleActivatedMemoriesCount(:,maxConfidenceIdx);
            end
            
            
            % get class idx with max count for each sample
            [~, idxs] = max(classCounts, [], 2);
            
            % get class label for each prediction
            labels = cell(length(idxs), 1);
            for i = 1:length(idxs)
                labels{i} = obj.classes{idxs(i)};
            end
        end
        
        
        function [results] = predictMap(obj, dataAddr)
            % Returns discriminators counts from Map for each memory
            % format: [nSamples, nClasses, nMemories]
            
            % initialize results
            results = zeros( size(dataAddr, 1), length(obj.classes), obj.nmemories );
            
            for i = 1:size(dataAddr, 1)
                for d = 1:length(obj.classes)
                    discriminator = obj.discriminators{d};
                    % get memory count for each memory and each discriminator
                    for m = 1:obj.nmemories
                        results(i, d, m) = WiSARD.mapGet(discriminator{m}, dataAddr(i, m));
                    end
                end
            end
        end
        
        function [results] = predictMatrix(obj, dataAddr)
            % Returns discriminators counts from Matrix for each memory
            % format: [nSamples, nClasses, nMemories]
            
            results = zeros( size(dataAddr, 1), length(obj.classes), obj.nmemories );
            
            for i = 1:size(dataAddr, 1)
                for d = 1:length(obj.classes)
                    
                    idxs = dataAddr(i, :) * obj.nmemories + [1:obj.nmemories];
                    results(i, d, :) = obj.discriminators{d}(idxs);
                end
            end
        end
        
        
        
        function [data_shuffled] = shuffleData(obj, data)
            % Shuffles bitstream using bits_order class parameter
            
            data_shuffled = data;
            for i = 1:size(data, 1)
                data_shuffled(i, obj.bits_order) = data(i, :);
            end
        end
        
        
        function [addrData] = bin2Addr(obj, data)
            % Converts binary streams to addresses using nbits parameter
            addrData = zeros(size(data, 1), obj.nmemories);
            
            k = 1;
            squares = 2.^(obj.nbits-1:-1:0);
            for i = 1:obj.nbits:size(data, 2)-obj.nbits
                addrData(:,k) = double(data(:, i:i+obj.nbits-1)) * squares';
                k = k+1;
            end
            
        end
       
       
    end
    methods (Static)
        function [val] = mapGet(map, addr)
            % Returns value of addr or 0 from map
            val = 0;
            if map.isKey(addr)
                val = map(addr);
            end
        end
        
        function [tValues, limits] = thermometerize(values, nLevels, limits)
            % Descretizes values using the thermometer method. Receives 
            % the values to descretize and the number of levels to use
            
            if nargin < 2
                nLevels = 5;
            end
            if nargin < 3 || sum(~isnan(limits)) == 0
                [dValues, limits] = discretize(values, nLevels+1);
                limits(1) = -Inf; limits(end) = Inf;
            else
                [dValues, limits] = discretize(values, limits);
            end
            dValues(isnan(dValues)) = 0;

            tValues = zeros(length(values), nLevels);
            for i=1:length(dValues)
                tValues(i, 1:dValues(i)-1) = 1;
            end

        end
        
        function [bData, limits] = binarizeData(data, method, varargin)
            % Transform data into binary representation using the specified method
            % Suported methods: 'thermometer'
            
            if nargin < 2
                method = 'thermometer';
            end
            
            % get data size
            [nsamples, nfeats] = size(data);
            
            if strcmpi(method, 'thermometer')
                if nargin < 3
                    nLevels = 5;
                else
                    nLevels = varargin{1};
                    if nargin >= 4
                       limits = varargin{2};
                    else
                       limits = nan(nLevels + 2, nfeats);
                    end
                end
                
                % initialize result variable
                bData = zeros(nsamples, nfeats * nLevels);
                
                
                % transform each column
                for f = 1:nfeats
                    [featData, limits(:, f)] = WiSARD.thermometerize(squeeze(data(:, f)), nLevels, limits(:, f));
                    bData(:, (f-1)*nLevels+1: f*nLevels) = featData;
                end
            else
                throw(MException('WiSARD:MethodNotSupported', ...
                  sprintf('The method %s is not supported for binarization. Refer to doc WiSARD to supported methods', method)));
            end

        end
        
    end
end