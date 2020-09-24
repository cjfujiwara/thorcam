function thorcam(mycams)

% The two cameras that we connect to for fluorescence analysis are:
% 10118 - X CAMERA
% 10148 - Y CAMERA
 
% Default Setting
tExp=64;                % Exposure time us
gGain=48;               % Gain in dB
ROIbg=[800 1000 1 200]; % ROI for background detection

mycams={'10118'};

% Load TLCamera DotNet assembly. The assembly .dll is assumed to be in the 
% same folder as the scripts.

%% Load Libraries to run the camera

% Directory where the dlls are located, this could depend on your comptuer
str='C:\Users\Solaire\Downloads\Thorlabcam\Scientific Camera Interfaces\MATLAB';

% Change directory to wher eyou stored the dlls
cd(str);
str=[pwd filesep 'Thorlabs.TSI.TLCamera.dll'];

if ~exist(str,'file')
    warning('Could not located the DLL to run the ThorCam! Exiting software.');
    return
end

% Load the NET assembly framework
fprintf('Loading the NET assembly ... ');
asmInfo=NET.addAssembly(str);
asmInfo.Classes;
disp('Dot NET assembly loaded.');

% Open the SDK
fprintf('Opening the camera SDK...');
tlCameraSDK = Thorlabs.TSI.TLCamera.TLCameraSDK.OpenTLCameraSDK;
disp('loaded.');


%% Create Graphical Interface
hF=figure(123);
set(hF,'Color','w','MenuBar','none','Toolbar','None');
clf
hF.CloseRequestFcn=@closeCB;

bStart=uicontrol('style','pushbutton','string','start','units',...
    'pixels','position',[0 0 50 20]);
bStop=uicontrol('style','pushbutton','string','stop','units',...
    'pixels','position',[50 0 50 20]);
bSettings=uicontrol('style','pushbutton','string','settings','units',...
    'pixels','position',[100 0 50 20],'Callback',@bSettingsCB);
bPD=uicontrol('style','pushbutton','string','photiode mode','units',...
    'pixels','position',[150 0 100 20],'Callback',@bPDCB);
cBkgd=uicontrol('style','checkbox','string','auto-background',...
    'units','pixels','Position',[250 0 150 20],'Callback',@cBkgdCB);

    function cBkgdCB(~,~)
        if cBkgd.Value
            keyboard
            imgBG=1024*ones(5000,5000);
        end
    end

cSub=uicontrol('style','checkbox','string','background subtract',...
    'units','pixels','position',[350 0 150 20]);
cFit=uicontrol('style','checkbox','string','fit?',...
    'units','pixels','position',[500 0 50 20],'Callback',@cFitCB);

    function cFitCB(~,~)
       if cFit.Value
          pRet.Visible='on';
       else
           pRet.Visible='off';
       end
    end   

pp=[];
    function bPDCB(~,~)
       hFPD=figure('Name','photodiode','toolbar','none','menubar','none');
       hFPD.Color='w';
       axes;
       pp=plot(0,0);
       xlabel('time (s)');
       ylabel('counts');
       set(gca,'FontSize',14);       
       bReset=uicontrol('style','pushbutton','string','clear data',...
           'units','pixels','position',[0 0 70 20],'callback',@bResetCB);       
        function bResetCB(~,~)
           T=[];
           Y=[];
           t0=now;
           cBGs=[];
        end       
    end


    function bSettingsCB(~,~)
        hFSet=figure('Name','Settings','Toolbar','none','menubar','none',...
            'resize','off');
        hFSet.Position(3:4)=[400 200];
        hFSet.Position(1:2)=hF.Position(1:2)+hF.Position(3:4)/2-...
            hFSet.Position(3:4)/2;
        
        % Read the camera settings
        gGain=double(opencams{1}.ConvertGainToDecibels(opencams{1}.Gain));
        tExp=double(opencams{1}.ExposureTime_us);
        
        textExp.String=[num2str(tExp) ' \mus'];   
        textGain.String=[num2str(gGain) ' dB'];

        tblAcq=uitable('units','pixels','ColumnName',{},'ColumnEditable',...
            [true true],'CellEditCallback',@chSet);
        tblAcq.Data=[gGain; tExp];
        tblAcq.RowName={'gain (dB)','exposure (us)'};
        tblAcq.Position(3:4)=tblAcq.Extent(3:4);        
        tblAcq.Position(1:2)=[50 10];
        
        
        tblROI=uitable('units','pixels','RowName',{});
        tblROI.Data=[1 1000 1 1920];
        tblROI.ColumnName={'x1','x2','y1','y2'};
        tblROI.ColumnWidth={50,50,50,50};
        tblROI.Position(3:4)=tblROI.Extent(3:4);        
        tblROI.Position(1:2)=[50 70];
        
        tblCLIM=uitable('units','pixels','RowName',{});
        tblCLIM.Data=ax.CLim;
        tblCLIM.ColumnName={'c1','c2'};
        tblCLIM.ColumnWidth={50,50};
        tblCLIM.Position(3:4)=tblCLIM.Extent(3:4);        
        tblCLIM.Position(1:2)=[50 120];
        tblCLIM.ColumnEditable=[true true];
        tblCLIM.CellEditCallback=@chCLIM;
        
        function chSet(tbl,data)
            r=data.Indices(1);
            val=data.NewData;            
            % Gain goes for 0 to 48 dB
            % Exposure goes from 64us to 51925252us
            
            switch r
                case 1                    
                    if val>=0 && val<=48
                        val=round(val,1);
                        disp(['Changing gain to ' num2str(val) ' dB']);
                        gVal=opencams{1}.ConvertDecibelsToGain(val);
                        opencams{1}.Gain=gVal;                        
                        gGain=opencams{1}.ConvertGainToDecibels(opencams{1}.Gain);
                        tbl.Data(data.Indices)=gGain;                        
                        textGain.String=[num2str(gGain) ' dB'];
                    else
                        tbl.Data(data.Indices)=data.PreviousData;                        
                    end
            
                case 2
                    if val>=64 && val<=1E5
                        val=round(val);
                        disp(['Changing exposure to ' num2str(val) ' us']);
                        opencams{1}.ExposureTime_us=uint32(val);
                        tbl.Data(r)=double(opencams{1}.ExposureTime_us);
                        tExp=tbl.Data(r);
                        textExp.String=[num2str(tExp) ' \mus'];                        
                    else
                        tbl.Data(r)=data.PreviousData;                        
                    end
            end          
        end
        
        function chROI(~,~)
            
        end
        
        function chCLIM(tbl,data)
            cThis=data.Indices(2);            
            cOther=mod(cThis,2)+1;            
            val=data.NewData;
            
            if cThis==1
                if val>=0 && val<=tbl.Data(cOther)
                   ax.CLim=[val tbl.Data(cOther)]; 
                else
                    tbl.Data(cThis)=data.PreviousData;
                end
            else
                if val<=1024 && val>=tbl.Data(cOther)
                   ax.CLim=[tbl.Data(cOther) val]; 
                else
                    tbl.Data(cThis)=data.PreviousData;
                end                
            end
        end
    end



ax=axes;
cla
hImg=imagesc(zeros(500));
caxis([0 1024]);
ax.XAxisLocation='top';
axis equal tight
colormap parula
hold on
xlabel('x pixels');
ylabel('y pixels');


pRet=plot(0,0,'r-');
pRet.Visible='off';

colorbar

textCounts=text(2,-2,'test','units','pixels','verticalalignment','top',...
    'color','k','fontweight','bold','fontsize',12);
textExp=text(100,-2,[num2str(tExp) ' us'],'units','pixels',...
    'verticalalignment','top','color','k','fontweight','bold',...
    'fontsize',12);
textGain=text(150,-2,[num2str(gGain) ' dB'],'units','pixels',...
    'verticalalignment','top','color','k','fontweight','bold',...
    'fontsize',12);

    function closeCB(fig,~)        
        stop(timerLive);        
        for ii=1:length(opencams)
            closeCamera(opencams{ii});            
        end        
        fprintf('Closing the camera SDK...');
        tlCameraSDK.Dispose;
        disp('done');    
        delete(fig)
    end

timerLive=timer('Name','liveupdate','executionmode','fixedspacing',...
    'period',.01);
timerLive.TimerFcn=@foo;

t0=now;
T=[];
Y=[];
cBGs=[];

imgBG=1024*ones(5000,5000);

    function foo(~,~)
        
        for ii=1:length(opencams)   
            imageFrame = opencams{ii}.GetPendingFrameOrNull;
            if ~isempty(imageFrame)
                imageData = imageFrame.ImageData.ImageData_monoOrBGR;
                imageHeight = imageFrame.ImageData.Height_pixels;
                imageWidth = imageFrame.ImageData.Width_pixels;   
                img = reshape(uint16(imageData), [imageWidth, imageHeight]);   
                img = img';
                img = imrotate(img,180);
                
       
                
                if cSub.Value
                    hImg.CData=img-imgBG;
                else  
                    hImg.CData=img;  
                end
                
                if cFit.Value && cSub.Value
                   data=img-imgBG;
                   fout=gaussfit2D(data);
                   cvals=coeffvalues(fout);
                   disp(cvals)
                   
                   tVec=linspace(0,2*pi,200);
                   
                   xvec=cvals(2)+2*cvals(3)*cos(tVec);
                   yvec=cvals(4)+2*cvals(5)*sin(tVec);
                   
                   set(pRet,'XData',xvec,'YData',yvec);
                   
                   

                   
                   
                   
                end
                
                t=(now-t0)*24*60*60;
                c=sum(sum(img));                
                T(end+1)=t;Y(end+1)=c;   
                cBG=sum(sum(img(ROIbg)));
                cBGs(end+1)=cBG;
                
                if length(T)>3E4
                    T=[];
                    Y=[];
                    cBGs=[];
                end
                
                if cBkgd.Value                            
                    if cBG>.5*max(cBGs) && c<sum(sum(imgBG))
                        figure(12)
                        clf
                        imgBG=img;                        
                        imagesc(imgBG);
                    end
                end                
                
                try
                    set(pp,'XData',T,'YData',Y);
                end
                textCounts.String=sprintf('%.4e',c);                
                clear img
                clear imageFrame
            end        
        end
        
    end

%% Acquire list of all cameras

opencams{1}=openCamera(mycams{1});
start(timerLive);


%% Helper functions

    function selCamera(~,~)
        
    end

    function outcams=refreshCameras(~,~)    

    % Remove old camera lists
    set(hF,'MenuBar','none');
    nDel=[];
    for n=1:length(hF.Children)
        if isequal(class(hF.Children(n)),'matlab.ui.container.Menu')
           nDel(end+1)=n;
        end
    end
    delete(hF.Children(nDel))

    % Update 
    m=uimenu('text','camera');    
    if (~isempty(tlCameraSDK))
        serialNumbers = tlCameraSDK.DiscoverAvailableCameras;
        if (serialNumbers.Count > 0)
            for iloop = 1:serialNumbers.Count
                camName=char(serialNumbers.Item(iloop-1));   
                outcams{iloop} =camName;                
                ms{iloop}=uimenu(m,'Text',camName,'UserData',camName,...
                    'callback',@selCamera);             
               if ismember(camName,mycams)
                  ms{iloop}.Checked='on'; 
               end            
            end
            uimenu(m,'Text','Refresh','Separator','on','callback',@refreshCameras);
        else
            outcams = {'No camera found'};
        end
    end

    end

    function tlCamera=openCamera(SN)     
        disp(['Opening camera ' SN]);
        tlCamera = tlCameraSDK.OpenCamera(SN, false);        
        % Get and Set camera parameters
        tlCamera.ExposureTime_us = uint32(tExp);        
        % The default black level should be zero
        tlCamera.BlackLevel=uint32(0);       
        % Set the default gain level to zero
        tlCamera.Gain=tlCamera.ConvertDecibelsToGain(gGain);                
        % Set operation mode to software testing
        tlCamera.OperationMode = Thorlabs.TSI.TLCameraInterfaces.OperationMode.SoftwareTriggered;    
        % Set frames per trigger to one
        tlCamera.FramesPerTrigger_zeroForUnlimited = 0;         
        % Arm the camera
        tlCamera.Arm;
        % Set trigger
        tlCamera.IssueSoftwareTrigger;        
        % Turn LED Off
        tlCamera.IsLEDOn=0;        
    end

    function closeCamera(tlCamera)
        disp('Closing camera');
        if (tlCamera.IsArmed)
            tlCamera.Disarm;
        end
        tlCamera.Dispose;        
        delete(tlCamera);           
    end

end

function fout=gaussfit2D(data)
data=double(data);
% Smooth the data to extract good guesses
 
dSmooth=imgaussfilt(data,15);

N0=max(max(dSmooth));

Z=dSmooth;
Z(dSmooth<N0*.5)=0;

Dx=1:size(data,2);
Dy=1:size(data,1);

X=sum(Z,1);
Y=sum(Z,2)';

% Subtract off background at beginning and end
dY=round(.05*size(data,1));
dX=round(.05*size(data,2));
Ybg=mean([Y(1:dY) Y(end-dY:end)]);
Xbg=mean([X(1:dX) X(end-dX:end)]);
X=X-1.05*Xbg;
Y=Y-1.05*Ybg;

% Remove any residual background
X(X<.5*max(X))=0;
Y(Y<.5*max(Y))=0;

% Find the sum totals;
Nx=sum(X);
Ny=sum(Y);

% Find the Center
Xc=mean(Dx(X>.9*max(X)));
Yc=mean(Dy(Y>.9*max(Y)));

% Calculate sigma in X and Y
Xs=1.5*sqrt(sum((Dx-Xc).^2.*X)/Nx);
Ys=1.5*sqrt(sum((Dy-Yc).^2.*Y)/Ny);



[xx,yy]=meshgrid(Dx,Dy);


Zguess=N0*exp(-(xx-Xc).^2./(2*Xs)^2).*exp(-(yy-Yc).^2./(2*Ys)^2);

data2=data;
xx2=xx;
yy2=yy;

xx2(Zguess<.15*N0)=[];
yy2(Zguess<.15*N0)=[];
data2(Zguess<.15*N0)=[];


bg=sum(sum(data-Zguess))/(length(X)*length(Y));

myfit=fittype('N0*exp(-(xx-Xc).^2./(2*Xs)^2).*exp(-(yy-Yc).^2./(2*Ys)^2)+cc',...
    'independent',{'xx','yy'},'coefficients',{'N0','Xc','Xs','Yc','Ys','cc'});
opt=fitoptions(myfit);
opt.StartPoint=[N0 Xc Xs Yc Ys bg];
opt.Weights=[];
fout=fit([xx2(:) yy2(:)],data2(:),myfit,opt);


end

