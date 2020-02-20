clear;
close all;

global Params;
global dataSet;
Params.NChirp = 128;                %һ֡��chirp����
Params.NChan = 4;                   %RxAn��,ADCͨ����
Params.NSample = 256;               %ÿ��chirp ADC������
Params.Fs = 10e6;                    %����Ƶ��
Params.c = 3.0e8;                   %����
Params.startFreq = 77.18e9;            %��ʼƵ�� ????
Params.freqSlope = 29.9817e12;      %chirp��б��
Params.bandwidth = (1.5351e9);        %����!!!!---��ʵ����
Params.lambda=Params.c/Params.startFreq;   %�״��źŲ���
Params.Tc = 160e-6;                 %chirp���� ????
Params.NChan_V = 2*4;               %MIMO�а��������������� Ntx*Nrx
Params.NChirp_V = Params.NChirp/2;  %������������ߵ����ݺ�chirp�����
Params.Tc_V = 2*Params.Tc;          %���������ߣ�chirp������Ҫ�ӱ�
Params.dopplerPFA = 0.03;           %������άcfarPFA
Params.rangePFA = 0.05;             %����άcfarPFA

%���ļ� fid���ڴ����ļ����ֵ,r��ʾֻ�� b��ʾ��������ʽ��
Params.fid_rawData = fopen('adc_data_TDM_10M.bin','rb');
Params.dataSizeOneFrame = Params.NSample*4*Params.NChirp*Params.NChan;

%��������
dp_updateFrameData(1);  %��i֡(1-8)

% ������������ߵ�����
dp_separateVirtualRx();

%2D FFT
%��dataSet.rawFrameDataִ�о���FFT 
dataSet.radarCubeData = processingChain_rangeFFT(1);

% [X,Y] = meshgrid(Params.c*(0:Params.NSample-1)*Params.Fs/2/Params.freqSlope/Params.NSample, ...
%     (-Params.NChirp/2:Params.NChirp/2 - 1)*Params.lambda/Params.Tc/Params.NChirp/2);    
% mesh(X,Y,abs(reshape(dataSet.radarCubeData(:,1,:),Params.NChirp,Params.NSample)));
% title('1d fft ���');
% ִ�ж�����FFT
dataSet.radarCubeData = processingChain_dopplerFFT(1);


%��NChirp_V����������Chan���
dataSet.sumFFT2D_radarCubeData = single(zeros(Params.NChirp_V,Params.NSample));   %����һ��NChirp_V�� NSample�еĿն�ά����
for chanNum = 1:Params.NChan_V
    %����ά�����Ϊ��ά����
    FFT2D_radarCubeData = reshape(dataSet.radarCubeData(:,chanNum,:),Params.NChirp_V,Params.NSample);   
    %��ģ->ȡlog->���
    dataSet.sumFFT2D_radarCubeData = (abs(FFT2D_radarCubeData)) + dataSet.sumFFT2D_radarCubeData;
%     mesh(X,Y,10*log10(abs(reshape(dataSet.radarCubeData(:,chanNum,:),Params.NChirp,Params.NSample))));
%     figure;
end

dopplerDimCfarThresholdMap = zeros(size(dataSet.sumFFT2D_radarCubeData));  %����һ����ά������dopplerάcfar��Ľ��
dopplerDimCfarResultMap = zeros(size(dataSet.sumFFT2D_radarCubeData));


[X,Y] = meshgrid(Params.c*(0:Params.NSample-1)*Params.Fs/2/Params.freqSlope/Params.NSample, ...
                (-Params.NChirp_V/2:Params.NChirp_V/2 - 1)*Params.lambda/Params.Tc_V/Params.NChirp_V/2);    

% ������ά�Ƚ���CFAR
for i = 1:Params.NSample
    dopplerDim = reshape(dataSet.sumFFT2D_radarCubeData(:,i),1,Params.NChirp_V);  %���һ������
    [cfar1D_Arr,threshold] = ac_cfar1D(12,2,Params.dopplerPFA,dopplerDim);  %����1D cfar
    dopplerDimCfarResultMap(:,i) = cfar1D_Arr.'; 
    dopplerDimCfarThresholdMap(:,i) = threshold.';
end

mesh(X,Y,(20*log10(dataSet.sumFFT2D_radarCubeData)));
xlabel('����(m)');ylabel('�ٶ�(m/s)');zlabel('�źŷ�ֵdB');
title('��������ͺ��2D_FFT���');
figure;

mesh(X,Y,20*log10(dopplerDimCfarThresholdMap));
xlabel('����(m)');ylabel('�ٶ�(m/s)');zlabel('�źŷ�ֵdB');
title('dopplerά��CFAR����ͼ');
figure;

mesh(X,Y,(dopplerDimCfarResultMap));
xlabel('����(m)');ylabel('�ٶ�(m/s)');zlabel('�źŷ�ֵdB');
title('dopplerά��CFAR�о����');
figure;

%����dopplerά�ȷ���Ѱ����dopplerάcfar�о���Ϊ1�Ľ��
saveMat = zeros(size(dataSet.sumFFT2D_radarCubeData));
for range = 1:Params.NSample
    indexArr = find(dopplerDimCfarResultMap(:,range)==1);
    objDopplerArr = [indexArr;zeros(Params.NChirp_V - length(indexArr),1)];   %���䳤��
    saveMat(:,range) = objDopplerArr; %����doppler�±�
end
% �����������doppler����
objDopplerIndex = unique(saveMat);  % unqiue�ǲ��ظ��ķ��������е���

% ����֮ǰdopplerά��cfar�����Ӧ���±�saveMat������Ӧ���ٶȽ���rangeά�ȵ�CFAR
rangeDimCfarThresholdMap = zeros(size(dataSet.sumFFT2D_radarCubeData));  %����һ����ά������rangeάcfar��Ľ��
rangeDimCfarResultMap = zeros(size(dataSet.sumFFT2D_radarCubeData));
i = 1;
while(i<=length(objDopplerIndex))
    if(objDopplerIndex(i)==0)   % ��Ϊ����������0,��ֹ����jȡ��0
        i = i + 1;
        continue;
    else    %�����ٶ��±����range CFAR
        j = objDopplerIndex(i);     % ����������ڵ���
        rangeDim = reshape(dataSet.sumFFT2D_radarCubeData(j, :),1,Params.NSample);  %���һ������
        % tip ���PFA���԰�,������õĵ�һЩ,�ڽ��з�֧�ۼ���ʱ��,���ܵĽ����û�м�⵽����
        % ��Ϊ�ڽ���rangeCFAR��ʱ��,�Ѹ��������ֵ���˵���,�������ڽ��з�ֵ�ۼ���ʱ��,�о������Ӧ�����ֵһֱ��С��
        % �r(�s���t)�q
        [cfar1D_Arr,threshold] = ac_cfar1D(3,2,Params.rangePFA,rangeDim);  %����1D cfar
        rangeDimCfarResultMap(j,:) = cfar1D_Arr; 
        rangeDimCfarThresholdMap(j,:) = threshold;
        i = i + 1;
        
        plot(20*log10(rangeDim));hold on;
        plot(20*log10(threshold));
        title(['����ά������dopplerIndex=',num2str(j)]);
        xlabel('����(m)');ylabel('�źŷ�ֵdB');
        figure;
        
    end
end
% plot((rangeDim));hold on;
% plot(threshold);
mesh(X,Y,(rangeDimCfarResultMap));
xlabel('����(m)');ylabel('�ٶ�(m/s)');zlabel('�źŷ�ֵ');
title('rangeCFAR֮���о����(��ֵ�ۼ�ǰ)');
xlim([0     Params.c*(Params.NSample-1)*Params.Fs/2/Params.freqSlope/Params.NSample]);
ylim([(-Params.NChirp_V/2)*Params.lambda/Params.Tc_V/Params.NChirp_V/2    (Params.NChirp_V/2 - 1)*Params.lambda/Params.Tc_V/Params.NChirp_V/2]);
figure;

% ���з�ֵ�۽�
[objDprIdx,objRagIdx] = peakFocus(rangeDimCfarResultMap);
objDprIdx(objDprIdx==0)=[]; %ȥ�������0
objRagIdx(objRagIdx==0)=[];
% ��������ĵ�,�����ٶȺ;���
objSpeed = ( objDprIdx - Params.NChirp_V/2 - 1)*Params.lambda/Params.Tc_V/Params.NChirp_V/2;
objRange = single(Params.c*(objRagIdx-1)*Params.Fs/2/Params.freqSlope/Params.NSample);
plot(objRange,objSpeed,'*r');
xlabel('����(m)');ylabel('�ٶ�(m/s)');
title('��ֵ�ۼ���');
xlim([0     Params.c*(Params.NSample-1)*Params.Fs/2/Params.freqSlope/Params.NSample]);
ylim([(-Params.NChirp_V/2)*Params.lambda/Params.Tc_V/Params.NChirp_V/2    (Params.NChirp_V/2 - 1)*Params.lambda/Params.Tc_V/Params.NChirp_V/2]);



% �������������нǶ�FFT
if(~isempty(objDprIdx))
    % ���ж����ղ���
     processingChain_dopplerCompensation(objDprIdx,objRagIdx,objSpeed)

    dataSet.angleFFTOut = processingChain_angleFFT(1,objDprIdx,objRagIdx);
end







%% 2D CFAR���֣���ʱ����
% [cfar_radarCubeData,tMap] = ac_cfar(12,4,10,4,0.0001,dataSet.sumFFT2D_radarCubeData);


% mesh(X,Y,abs(reshape(dataSet.radarCubeData(:,1,:),Params.NChirp,Params.NSample)));
%��ά��ͼ
%��������ϵ,���������ٶ�
% [X,Y] = meshgrid(Params.c*(0:Params.NSample-1)*Params.Fs/2/Params.freqSlope/Params.NSample, ...
%                 (-Params.NChirp/2:Params.NChirp/2 - 1)*Params.lambda/Params.Tc/Params.NChirp/2);    
% mesh(X,Y,(dataSet.sumFFT2D_radarCubeData));
%           title("logǰ");  figure;
% mesh(X,Y,20*log10(dataSet.sumFFT2D_radarCubeData));
% xlabel('����(m)');ylabel('�ٶ�(m/s)');zlabel('�źŷ�ֵ');
% title('2D FFT(4��������Ӻ�)');
% xlim([0     Params.c*(Params.NSample-1)*Params.Fs/2/Params.freqSlope/Params.NSample]);
% ylim([(-Params.NChirp/2)*Params.lambda/Params.Tc/Params.NChirp/2    (Params.NChirp/2 - 1)*Params.lambda/Params.Tc/Params.NChirp/2]);
% hold on;
% 
% mesh(X,Y,20*log10(tMap));
% xlabel('����(m)');ylabel('�ٶ�(m/s)');zlabel('�źŷ�ֵ');
% title('������ͼ & 2dfft');
% xlim([0     Params.c*(Params.NSample-1)*Params.Fs/2/Params.freqSlope/Params.NSample]);
% ylim([(-Params.NChirp/2)*Params.lambda/Params.Tc/Params.NChirp/2    (Params.NChirp/2 - 1)*Params.lambda/Params.Tc/Params.NChirp/2]);
% figure;
% 
% 
% mesh(X,Y,(cfar_radarCubeData));
% xlabel('����(m)');ylabel('�ٶ�(m/s)');zlabel('�о����1��0');
% title('2D FFT cfar��');
% xlim([0     Params.c*(Params.NSample-1)*Params.Fs/2/Params.freqSlope/Params.NSample]);
% ylim([(-Params.NChirp/2)*Params.lambda/Params.Tc/Params.NChirp/2    (Params.NChirp/2 - 1)*Params.lambda/Params.Tc/Params.NChirp/2]);





% rangeProfileData = dataSet.radarCubeData(1, 1, :);
% chFFT = rangeProfileData(:);    %����ά���ݱ��һ������
% channelData = 20 * log10 (abs(chFFT));
% plot(channelData);

%% ����

% ����һ֡�����ݲ���ִ�о���FFT
% ����:frameIdx - ֡����(��1��ʼ)
% ���:dataSet.rawFrameData - Ҫ����FFT����ά����
%      dataSet.radarCubeData - ִ�о���FFT�����ά����
function dp_updateFrameData(frameIdx)
    global Params;
    global dataSet;
    
    rawDataComplex = dp_loadOneFrameData(Params.fid_rawData,Params.dataSizeOneFrame,frameIdx);
    dataSet.rawDataUint16 = uint16(rawDataComplex);
    % time domain data y value adjustments
    %������65534������ʾΪ����-2
    %��������Ƶ�����λΪ1(�����ڵ���2��15�η�)��ô������Ǹ������ټ�ȥ65536
    timeDomainData = rawDataComplex - ( rawDataComplex >=2.^15).* 2.^16;
    frameData = dp_reshape2LaneLVDS(timeDomainData);

    %����ĿǰiqSwapSel = 0
    %frameData�ĵ�һ��I��1i*�ڶ���Q��Ϊһ������(����1i��ʾһ��������λ,Ϊ���Է������˱���i����)
    frameCplx = frameData(:,1) + 1i*frameData(:,2); 

    %��ʼ����Ŷ��֡����λ���� (Nchirp,NChan,NSample)
    frameComplex = single(zeros(Params.NChirp, Params.NChan, Params.NSample));

    % ���ǵ�chInterleave = 1 
    % non-interleave data
    % ��֮ǰ��Ÿ����ľ���frameCplx reshapeΪNSample*NChan��,NChirp�еĶ�ά����,��ȡת��
    % ��Ϊ֮ǰ��frameCplx����ÿ��chirpΪ'����'��
    % ������temp������� ��:ĳ��chirp������(Rx��˳�����е�ADC��������) ��:0_0-255 1_0-255 ```3_0-255 
    temp = reshape(frameCplx, [Params.NSample * Params.NChan, Params.NChirp]).';
    % ��temp�е�ÿһ��reshapeΪNSample*NChan�Ķ�ά����,ת�ú��ٷ���frameComplex��NChirpά����
    for chirp=1:Params.NChirp                            
    frameComplex(chirp,:,:) = reshape(temp(chirp,:), [Params.NSample, Params.NChan]).';
    end
    % ���浽ȫ�ֱ���
    dataSet.rawFrameData = frameComplex;
end

%��bin�ļ��м���һ֡������
% ����:fid_rawData - bin�ļ����
%      dataSizeOneFrame - һ֡�����ݴ�С(�ֽ�)
%      frameIdx - ֡����
% ���:rawData - һ֡������
function [rawData] = dp_loadOneFrameData(fid_rawData, dataSizeOneFrame, frameIdx)
    % ���¶�λ�ļ�λ��
    % ��ͷ��ʼ����ƫ��(frameIdx-1)*dataSizeOneFrame���ֽ�
    fseek(fid_rawData,(frameIdx-1)*dataSizeOneFrame,'bof');
    
    try   %����ļ��򿪳ɹ�
    %data:��ȡ������ 
    %count:��ȡ���ݵ����� 
    %[M,N]��ȡ���ݵ�M*N����������ݰ��д�� 262144��һ֡�������� 
    %262144 = ÿ��chirpADC������*2(I&Q)*Rx��*chirp���� 
    %uint16 ���ݸ�ʽΪʮ��λ�޷�������
    %�����и�����:uint16����Ľ���Ǻ����������һ�������ǲ�û�������������������2��aabb�ߵ�Ϊbbaa
    %��Ҳ��֪��ΪʲôҪuint16=>single,������Ϊ�˼ӿ�����ٶȰ�,single�Ǳ�double�����ٶȿ��
    rawData = fread(fid_rawData,dataSizeOneFrame/2,'uint16=>single');
    catch
        error("error reading binary file");
    end
    fclose(fid_rawData);
end

% �����ݱ�Ϊ������ʽ
function [frameData] = dp_reshape2LaneLVDS(rawData)
    % Convert 2 lane LVDS data to one matrix 
    rawData4 = reshape(rawData, [4, length(rawData)/4]);    %��rawData�����Ϊ[M,N]�ľ���,��������(4��Ϊ1��)ţXţX����

    rawDataI = reshape(rawData4(1:2,:), [], 1);     %rawData4(1:2,:)��ʾȡ����rawData4��1,2��(1,2�зŵĶ���I����)
                                                    %ȡ��1,2��֮����reshapeΪһ��I����
                                                    
    rawDataQ = reshape(rawData4(3:4,:), [], 1);     %rawData4(3:4,:)��ʾȡ3,4��,�ٰ�3,4������reshapeΪһ��Q����
    
    frameData = [rawDataI, rawDataQ];   %�������һ��I���ݺ�Q���ݺϲ�Ϊһ��n��2�еľ���(һ֡�����ݣ�128��chirp)
end


% ������������ߵ�����
function  dp_separateVirtualRx()
    global Params;
    global dataSet;
    
    NChirp = Params.NChirp;
    NChan = Params.NChan;
%     NRangeBin = Params.NSample;
    % ��chirp����Ϊ2 4 6....ż�����ҳ����ŵ���Ӧ����������5678��λ��
    for i = 2:2:NChirp      
        for j = 1:NChan
            dataSet.rawFrameData(i-1,j+4,:) = dataSet.rawFrameData(i,j,:);
        end
    end
    
    % ��ȡ��Ϻ�ɾ��chirp����Ϊ2 4 6...ż������   �����ᵼ��chirp�������Ϊÿһ֡��ԭ��һ��ĸ�������128/2
    dataSet.rawFrameData(2:2:NChirp,:,:) = [];
end
% �����ݽ��о���FFT
function [radarCubeData] = processingChain_rangeFFT(rangeWinType)
    global Params;
    global dataSet;
    
    NChirp = Params.NChirp_V;
    NChan = Params.NChan_V;
    NRangeBin = Params.NSample;
    
    % ������ѡ��
    switch rangeWinType
        case 1 %hann
            win = hann(NRangeBin);
        case 2 %blackman
            win = blackman(NRangeBin);
        otherwise
            win = rectwin(NRangeBin);
    end
    %��ʼ��һ����ά������FFT���
    radarCubeData = single(zeros(NChirp,NChan,NRangeBin));
    for chirpIdx=1:NChirp
        for chIdx = 1: NChan
            frameData(1,:) = dataSet.rawFrameData(chirpIdx,chIdx,:);    
            frameData = fft(frameData .* win', NRangeBin);      %����NRangeBin���range-FFT
            radarCubeData(chirpIdx,chIdx,:) = frameData(1,:);   %��FFT�Ľ������radarCubeData
        end
    end
end

% �����ݽ��ж�����FFT
function [radarCubeData] = processingChain_dopplerFFT(rangeWinType)
    global Params;
    global dataSet;
    
    NChirp = Params.NChirp_V;
    NChan = Params.NChan_V;
    NRangeBin = Params.NSample;
    
    % ������ѡ��
    switch rangeWinType
        case 1 %hann
            win = hann(NChirp);
        case 2 %blackman
            win = blackman(NChirp);
        otherwise
            win = rectwin(NChirp);
    end
    %��ʼ��һ����ά������FFT���
    radarCubeData = single(zeros(NChirp,NChan,NRangeBin));
    for chIdx=1:NChan
        for rangeIdx = 1: NRangeBin
            frameData(1,:) = dataSet.radarCubeData(:,chIdx,rangeIdx);    
            frameData = fftshift(fft(frameData .* win', NChirp));      %����NChirp���doppler-FFT
                                                                       %fftshift�ƶ���Ƶ�㵽Ƶ���м�---���Ǻܶ�
            radarCubeData(:,chIdx,rangeIdx) = frameData(1,:);   %��FFT�Ľ������radarCubeData
        end
    end
end

% ����:NTrainRange - ����ά��ѵ����Ԫ����
% NGuardRange - ����ά�ȱ�����Ԫ����
% NTrainDoppler - ������ά��
% NGuardDoppler
% PFA - �����龧��
% inputRDM - range doppler map
% ���: cfar_radarCubeData - �о����
% tMap - ����ͼ
function [cfar_radarCubeData,tMap] = ac_cfar(NTrainRange,NGuardRange,NTrainDoppler,NGuardDoppler,PFA,inputRDM)
    global Params; 
    cfar_radarCubeData = zeros(Params.NChirp_V,Params.NSample);   %���cfar��Ľ��,
    tMap = NaN*zeros(Params.NChirp_V,Params.NSample);                 %�������ͼ
    %����CUT�ķ�Χ
    for i = NTrainRange+NGuardRange+1 : Params.NSample-NTrainRange-NGuardRange
        for j = NTrainDoppler+NGuardDoppler+1 : Params.NChirp_V-NTrainDoppler-NGuardDoppler
            %���ÿ�ε�����ѵ����Ԫ������ֵ
            noiseLevel = zeros(1,1);
            %��ָ����Χ��(guardCell֮��)������ǰCUTѵ����Ԫ
            for p = i-NTrainRange-NGuardRange : i+NTrainRange+NGuardRange
                for q = j-NTrainDoppler-NGuardDoppler : j+NTrainDoppler+NGuardDoppler
                    if(abs(i-p)>NGuardRange || abs(j-q)>NGuardDoppler)
                        %��Ϊ���ǵ�RDM������(��)��range,������(��)��doppler
                        noiseLevel = noiseLevel + (inputRDM(q,p));  %��q��,��p��,
                    end
                end
            end
            
            %����������ƽ��ֵ��������
            totalNTrain = (2*(NTrainRange+NGuardRange)+1)*(2*(NTrainDoppler+NGuardDoppler)+1)-(2*NGuardRange+1)*(2*NGuardDoppler+1);
            a = totalNTrain*((PFA^(-1/totalNTrain))-1);
            threshold = (noiseLevel / totalNTrain);
            threshold =  a*threshold;
            
            tMap(j,i) = threshold;
            CUT = inputRDM(j,i);
            
           %�о�
            if(CUT < threshold)
                cfar_radarCubeData(j,i) = 0;
            else
                cfar_radarCubeData(j,i) = 1; 
            end
            
        end
    end
end

function [cfar1D_Arr,threshold] = ac_cfar1D(NTrain,NGuard,PFA,inputArr)
    cfar1D_Arr = zeros(size(inputArr));
    threshold = zeros(size(inputArr));

    totalNTrain = 2*(NTrain);
    a = totalNTrain*((PFA^(-1/totalNTrain))-1);
    %��ƽ��ֵ
    for i = NTrain+NGuard+1:length(inputArr)-NTrain-NGuard
        avg = mean([inputArr((i-NTrain-NGuard):(i-NGuard-1))   inputArr((i+NGuard+1):(i+NTrain+NGuard))]);
        threshold(1,i) = a.*avg;
        %����threshold�Ƚ�
        if(inputArr(i) < threshold(i))
            cfar1D_Arr(i) = 0;
        else
            cfar1D_Arr(i) = 1;
        end
    end
    
end
 
% ����: inputCfarResMat - ���з�ֵ�۽��Ķ�ά����,������rangeάCFAR�о���õ��Ľ������
% ���: row - �����������(��Ӧ�ٶ�)
% column - �����������(��Ӧ����)
function [row,column] = peakFocus(inputCfarResMat)
    global dataSet;
    global Params;
    j = 1;
    row = zeros([1 Params.NSample]);
    column = zeros([1 Params.NSample]);
    [d,r] = find(inputCfarResMat==1);   %Ѱ�ҽ���rangeάcfar����о�Ϊ1������
    for i = 1 : length(d)
        peakRow = d(i);
        peakColumn = r(i);
        peak = dataSet.sumFFT2D_radarCubeData(peakRow,peakColumn);  %����֤�ķ�ֵ
        % �ڸ�����3*3�����е������бȽ�,����м���������ֵ,���ж�Ϊ1  tip:����֪��������̫���ĺ���� �ѩҩn�ѩ�
        % �Ѹ�����8+1����ȡ����
        % ����֮ǰ���е�2��cfar,��Ϊ��TrainCell��GuardCell�����Բ���������Ե
        tempArr =[dataSet.sumFFT2D_radarCubeData(peakRow-1,peakColumn-1) , dataSet.sumFFT2D_radarCubeData(peakRow-1,peakColumn) ,  dataSet.sumFFT2D_radarCubeData(peakRow-1,peakColumn+1), ...
                  dataSet.sumFFT2D_radarCubeData(peakRow,peakColumn-1)   ,                     peak                             ,  dataSet.sumFFT2D_radarCubeData(peakRow,peakColumn+1), ...
                  dataSet.sumFFT2D_radarCubeData(peakRow+1,peakColumn-1) , dataSet.sumFFT2D_radarCubeData(peakRow+1,peakColumn) ,  dataSet.sumFFT2D_radarCubeData(peakRow+1,peakColumn+1)] ;    
        truePeak = max(tempArr);     % Ѱ�����ֵ
        if(truePeak == peak)         %����м�������ֵ�ͱ��浱ǰ������
            row(j) = peakRow;
            column(j) = peakColumn;
            j = j+1;
        end
    end
end


% �����ղ���
% ���룺
% objDprIndex - �����Ӧ�Ķ�����ά����
% objRagIndex - �����Ӧ�ľ���ά����
% Vest - �״����������ٶ�
function processingChain_dopplerCompensation(objDprIndex,objRagIndex,Vest)
    global Params;
    global dataSet;
    for n = 1:length(objDprIndex)
        deltePhi = 4*pi*Vest(n)*Params.Tc/Params.lambda;  %����������
        %���в���
        dataSet.radarCubeData(objDprIndex(n),5:8,objRagIndex(n)) = dataSet.radarCubeData(objDprIndex(n),5:8,objRagIndex(n)).*exp(-1i*1*deltePhi);
    end
    
end

% ���룺rangeWinType - ������ѡ��
% objDprIndex - �����Ӧ�Ķ�����ά����
% objRagIndex - �����Ӧ�ľ���ά����
% �����angleFFTOut - ���нǶ�FFT����Ľ������ά���� - �ڼ������壬�� - FFT�����
function [angleFFTOut] = processingChain_angleFFT(rangeWinType,objDprIndex,objRagIndex)

    global Params;
    global dataSet;
    angleFFTNum = 180;
    %NChirp = Params.NChirp_V;
    NChan = Params.NChan_V;
    %NRangeBin = Params.NSample;
    NObject = length(objDprIndex);  %����������Ŀ
    % ������ѡ��
    switch rangeWinType
        case 1 %hann
            win = hann(NChan);
        case 2 %blackman
            win = blackman(NChan);
        otherwise
            win = rectwin(NChan);
    end
    %��ʼ��һ����ά������FFT���
    angleFFTOut = single(zeros(NObject,angleFFTNum));
    for i=1:NObject
        frameData(1,:) = dataSet.radarCubeData(objDprIndex(i),:,objRagIndex(i));   
        % �и����⣬���ﵽ���Ǽ������FFT
        % �����㣬�����𲻴����ⲻ�üӴ���������
        frameFFTData = fftshift(fft(frameData, angleFFTNum));      %����NChan���angler-FFT
                                                                   %fftshift�ƶ���Ƶ�㵽Ƶ���м�---���Ǻܶ�
                                                                   %��+����-��
        angleFFTOut(i,:) = frameFFTData(1,:);   %��FFT�Ľ������angleFFTOut
        
%         figure;plot(abs(angleFFTOut(i,:)));
        maxIndex= find(abs(angleFFTOut(i,:))==max(abs(angleFFTOut(i,:))));
        angle = asin((maxIndex - angleFFTNum/2 - 1)*2/angleFFTNum) * 180/pi;
        fprintf("object%d angle:%.2f��\n",i,angle);
    end

end


