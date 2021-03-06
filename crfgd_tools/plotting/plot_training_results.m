% if not working try starting matlab using
% "LD_PRELOAD="/usr/lib/x86_64-linux-gnu/libstdc++.so.6.0.21" matlab"

%% Setup
data_set = 'pascal'; %add more optrions
imname = '2007_002227'; %pascal

model = '../training/filterbank/net_train_deploy.prototxt';
weights = '../training/snapshots/filterbank_train_iter_2928.caffemodel'; 

data_root = '/media/cvia/disk2/Data/test_pascal/VOCdevkit/VOC2012'; %point this to pascal root folder

do_intermediate_iterations = false;
do_plot_filters = true;
do_computations_in_matlab = false;
%% Do stuff
caffe_matlab_root = '../../matlab';
addpath(caffe_matlab_root);
caffe.reset_all();

%% do stuff
switch data_set
    case 'pascal'
        im_path = fullfile(data_root,'JPEGImages',[imname '.jpg']);
        seg_path = fullfile(data_root,'SegmentationClass',[imname '.png']);
end

gt = imread(seg_path);
im = imread(im_path);

switch data_set
    case 'pascal'
        im_mean = zeros(1,1,3);
        im_mean(1,1,1) = 104.008;
        im_mean(1,1,2) = 116.669;
        im_mean(1,1,3) = 122.675;
        ims = [640 640];
end

caffe_input = zeros(ims(1),ims(2),3,1,'single');
caffe_input(1:size(im,1),1:size(im,2),:,1) = single(bsxfun(@minus,double(im(:,:,[3 2 1])),im_mean));
caffe_input = permute(caffe_input,[2 1 3 4]);
caffe.set_mode_cpu();

net = caffe.Net(model, weights, 'test');    

net.blobs('data').reshape([ims(2) ims(1) 3 1]);
net.reshape();
res = net.forward({caffe_input});

if length(res) == 2
    prob = res{2};                                    
else
    prob = res{1};                                    
end                               
prob = permute(prob,[2 1 3]);

[~,seg_post]= max(prob(1:size(im,1),1:size(im,2),:),[],3);           

prob_pre = net.blobs('score_pre').get_data();                                   
prob_pre = permute(prob_pre,[2 1 3]);

[~,seg_pre]= max(prob_pre(1:size(im,1),1:size(im,2),:),[],3);           

gt = gt + 1;
gt(gt == 255) = 0;
try
    dim_data_orig = net.blobs('deep_feature_dimension_mapping').get_data();
catch err
    try
        dim_data_orig = net.blobs('edges').get_data();
    catch err
        dim_data_orig = zeros(ims(2),ims(1),3,'single');
        warning('unable to extract deep feature dimension mapping')
    end
end
dim_data_orig = permute(dim_data_orig,[2 1 3]);  
dim_data = dim_data_orig(1:size(im,1),1:size(im,2),:);

% figure;
subplot(2,4,1);imshow(im);title('im');
subplot(2,4,2);imshow(seg_pre,[]);title('seg pre');                                                                                                                                                                           
subplot(2,4,3);imshow(seg_post,[]);title('seg post');     
subplot(2,4,4);imshow(gt,[]);title('ground truth');  

subplot(2,4,5);imshow(dim_data(:,:,1),[]);title('f1 val');     
subplot(2,4,6);imshow(dim_data(:,:,2),[]);title('f2 val');     
subplot(2,4,7);imshow(dim_data(:,:,3),[]);title('f3 val');     

% net weights
try
    ww_unary = net.params('crf_filterbank_ed',1).get_data();
    ww = net.params('crf_filterbank_ed',2).get_data();
    ww = weights_caffe_to_matlab(ww);
    fprintf('unary weight: %f \n', ww_unary)
catch err
    warning('unable to extract crf params.')
end

if do_plot_filters
    switch data_set
        case 'pascal'           
            for ff = 1:3
                figure('name',sprintf('switch energies, feat dim %d',ff))
                for c1 = 1:21
                    for c2 = 1:21
                        subplot(21,21,c1+21*(c2-1));
                        
                        Ec1c2 = ww(:,:,3*(c1-1)+ff,c2);
                        Ec2c1 = ww(:,:,3*(c2-1)+ff,c1);
                        Ec1c1 = ww(:,:,3*(c1-1)+ff,c1);
                        
                        E_switch = Ec1c2 + Ec2c1.' - Ec1c1 - Ec1c1.';
                        
                        surf(E_switch)
                        title([num2str(c1) ' to ' num2str(c2) ', f: ' num2str(ff)])
                    end
                end
            end
    end
end
n_classes = size(prob_pre,3);

figure;
for i = 1:n_classes
    subplot(2,n_classes,i);imshow(prob_pre(:,:,i));title(sprintf('pre %d',i));
    subplot(2,n_classes,i+n_classes);imshow(prob(:,:,i));title(sprintf('post %d',i));
end

skip_pw_term = false;
if do_intermediate_iterations
    figure('name','intermediate steps')
    for i = 1:n_classes
        subplot(6,n_classes,i);imshow(prob_pre(:,:,i));title(sprintf('it %d',0));
    end
    
    for i = 1:4
        tmp_mod_file = './tmp.prototxt';
        fidw = fopen(tmp_mod_file,'w');
        fidr = fopen(model);
        
        tline = fgets(fidr);
        while ischar(tline)
            fprintf(tline)
            if ~isempty(strfind(tline,'num_iterations:')) %change number of iterations by rewriting proto
                tline(25) = num2str(i);
                if skip_pw_term
                    fprintf(fidw,'        skip_pw_term: true');
                end
            end
            fprintf(fidw,tline);
            tline = fgets(fidr);
        end
        
        fclose(fidw);
        fclose(fidr);
        
        caffe.set_mode_cpu();
        
        net = caffe.Net(tmp_mod_file, weights, 'test');    
        
        net.blobs('data').reshape([ims(2) ims(1) 3 1]);
        net.reshape();
        res = net.forward({caffe_input});
        
        prob_im = res{1};                                    
        prob_im = permute(prob_im,[2 1 3]);
        
        for jj = 1:n_classes
            subplot(6,n_classes,jj + i*n_classes);imshow(prob_im(:,:,jj));title(sprintf('it %d',i));
        end
        
    end
    delete(tmp_mod_file)
end

for jj = 1:n_classes
    subplot(6,n_classes,jj + 5*n_classes);imshow(prob(:,:,jj));title(sprintf('it %d',5));
end
