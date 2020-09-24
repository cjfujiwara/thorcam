function hF=openCam(sn,tlCameraSDK)
% SUPER STUPID AND CLUNKy
evalin('base','results=[0 0 0 0 0 0 0 ]');
% The two cameras that we connect to for fluorescence analysis are:
% 10118 - X CAMERA
% 10148 - Y CAMERA
 
% Default settings for the camera.  These are loaded upon a new connection
% to the camera.
tExp=1005;                % Exposure time us
gGain=10;               % Gain in dB
ROIbg=[800 1000 1 200]; % ROI for background detection

doDebug=0;
%% Open the camera
cam=openCamera(sn);

[ROI,xVec,yVec]=readROI;
imgBG=zeros(length(yVec),length(xVec));

cameraMode='Live';

% Stucture for live settings
live=struct;
live.Fit=false;
live.AutoBackground=false;
live.ImgBackground=imgBG;
live.BackgroundSubtract=false;

% Structure for triggered settings
trig=struct;
trig.Fit=false;
trig.AutoBackground=false;
trig.ImgBackground=imgBG;
trig.BackgroundSubtract=false;
trig.Mode=2; % 0 : one image, 1 : background then image, 2 : image then background
trig.NumImages=0;
trig.Images={};
%% Create Graphical Interface

% Initialize the figure GUI
hF=figure(str2num(sn));
set(hF,'Color','w','MenuBar','none','Toolbar','None',...
    'CloseRequestFcn',@closeCB);
if isequal(sn,'10118')
    hF.Name=['MOT CAMERA SN - ' sn ' X'];
else
    hF.Name=['MOT CAMERA SN - ' sn ' Y'];
end
clf

% Callback function for closing the camera GUI
    function closeCB(fig,~)        
        % Stop the timers
        stop(timerLive);       
        stop(timerTrig);
        % Wait for timers to stop (not working?)
        pause(1);
        % Delete the timer objects
        delete(timerLive);
        delete(timerTrig);
        % Disconnect from the camera
        closeCamera(cam);            
        disp('done');    
        % Delete the figure
        delete(fig)
    end

% Add the cameras and refresh menu 
m=uimenu('text','File'); 
mSett=uimenu(m,'Text','Settings','callback',@settingsGUI,'Separator','on');


%%%%%%%%%%%%%%%% Initialize image and axis %%%%%%%%%%%%%%%%%%%%%%%
ax=axes;
cla
hImg=imagesc(xVec,yVec,imgBG);
set(ax,'XAxisLocation','top','fontsize',14,'fontname','arial',...
    'CLim',[0 1024]);
xlabel('x pixels');ylabel('y pixels');
axis equal tight
colormap parula
cbar=colorbar;
cbar.Label.String='counts';
hold on

% Initialize the fit reticle
pRet=plot(0,0,'r-','Visible','off');
pp=[];

% Text objects at bottom of axis for summary of settings
textCounts=text(2,-2,'test','units','pixels','verticalalignment','top',...
    'color','k','fontweight','bold','fontsize',12);
textExp=text(100,-2,[num2str(tExp) ' us'],'units','pixels',...
    'verticalalignment','top','color','k','fontweight','bold',...
    'fontsize',12);
textGain=text(170,-2,[num2str(gGain) ' dB'],'units','pixels',...
    'verticalalignment','top','color','k','fontweight','bold',...
    'fontsize',12);
textFit=text(2,2,'boop','units','pixels','verticalalignment','bottom',...
    'color','r','fontweight','bold','fontsize',12,'visible','off');

%%%%%%%%%%%%%%%% Graphics for settings %%%%%%%%%%%%%%%%%%%%%%%

% Radio button group for operation mode
bg = uibuttongroup('units','pixels','backgroundcolor','w',...
    'position',[0 0 80 40],'SelectionChangedFcn',@chCameraMode);              
% Create three radio buttons in the button group.
uicontrol(bg,'Style','radiobutton','String','Live',...
    'Position',[0 0 80 20],'units','pixels','backgroundcolor','w');
uicontrol(bg,'Style','radiobutton','String','Triggered',...
    'Position',[0 20 80 20],'units','pixels','backgroundcolor','w');
        
% Callback function for when the mode of the camera is changed
    function chCameraMode(~,event)                
        str=event.NewValue.String;
        switch str
            % Switch the camera to live mode
            case 'Live'     
                disp('Switching camera to live mode');
                cameraMode='Live';
                stop(timerTrig);            % Stop watching for triggers
                pause(0.5);                 % Wait
                hImg.CData=hImg.CData*0;    % Clear the display image
                textCounts.String='0';      % Clear the display counts
                cam.Disarm;                 % Stop the camera
                cam.OperationMode=...       % Change to software trigger
                    Thorlabs.TSI.TLCameraInterfaces.OperationMode.SoftwareTriggered;
                cam.Arm;                    % Start the camera
                trig.numImages=0;
                trig.Images={};
                mSett.Enable='on';
                start(timerLive);           % Start software trigger timer
            % Switch the camera to triggered mode
            case 'Triggered'
                cameraMode='Triggered';
                disp('Switching camera to triggered mode');
                stop(timerLive);            % Stop software triggers           
                pause(0.5);                 % Wait
                hImg.CData=hImg.CData*0;    % Clear the display image
                textCounts.String='0';      % Clear the display counts
                cam.Disarm;                 % Stop the camera
                cam.OperationMode=...       % Change to hardware trigger
                    Thorlabs.TSI.TLCameraInterfaces.OperationMode.HardwareTriggered;
                cam.Arm;                    % Start the camera
                trig.numImages=0;
                trig.Images={};
                mSett.Enable='off';
                start(timerTrig);           % Start watching for triggers
        end      
    end

% Timers for updates (this should change to nly one timer)
timerTrig=timer('Name','TrigChecker','executionmode','fixedspacing',...
    'period',0.02,'TimerFcn',@trigCB);
timerLive=timer('Name','liveupdate','executionmode','fixedspacing',...
    'period',0.001,'TimerFcn',@liveCB);

t0=now;
T=[];
Y=[];
cBGs=[];
start(timerLive);
%% Settings callback
    function settingsGUI(~,~)
        % Read the camera settings
        gGain=double(cam.ConvertGainToDecibels(cam.Gain));
        tExp=double(cam.ExposureTime_us);
        
        % Store the camera settings
        [ROI,xVec,yVec]=readROI;
        textExp.String=[num2str(tExp) ' \mus'];   
        textGain.String=[num2str(gGain) ' dB'];        
        
        % Make new figure for settings
        str=[hF.Name ' Settings'];
        hFSet=figure('Name',str,'Toolbar','none','menubar','none',...
            'resize','off','color','w');
        hFSet.Position(3:4)=[600 300];
        hFSet.Position(1:2)=hF.Position(1:2)+hF.Position(3:4)/2-...
            hFSet.Position(3:4)/2;        
        
        %%%%%%%%%%%%%%%%%%%% Global settings panel %%%%%%%%%%%%%%%%%%%%%%%%
        % Panel for adjusting main settings
        hpMain=uipanel('parent',hFSet,'units','pixels','title',...
            'global settings','position',[10 10 250 280],...
            'backgroundcolor','w');  
        
        % Table for adjusting gain and exposure
        tblAcq=uitable(hpMain,'units','pixels','ColumnName',{},...
            'ColumnEditable',[true true],'CellEditCallback',@chSet,...
            'Data',[gGain; tExp],'RowName',{'gain (dB)','exposure (us)'},...
            'ColumnWidth',{50 50});
        tblAcq.Position(3:4)=tblAcq.Extent(3:4);        
        tblAcq.Position(1:2)=[10 10];        
        
        % Table for adjusting hardware ROI
        tblROI=uitable(hpMain,'units','pixels','RowName',{},'Data',ROI,...
            'ColumnEditable',[true true true true],'CellEditCallback',@chROI,...
            'ColumnName',{'x1','x2','y1','y2'},'ColumnWidth',{50 50 50 50});
        tblROI.Position(3:4)=tblROI.Extent(3:4);        
        tblROI.Position(1:2)=[10 70];
           
        % Table for adjusting color limits on plot
        tblCLIM=uitable(hpMain,'units','pixels','RowName',{},...
            'Data',ax.CLim,'ColumnWidth',{50 50},'ColumnName',{'c1','c2'},...
            'ColumnEditable',[true true],'CellEditCallback',@chCLIM); 
        tblCLIM.Position(3:4)=tblCLIM.Extent(3:4);        
        tblCLIM.Position(1:2)=[10 120];   
        
        % Checkbox for debug mode
        uicontrol('parent',hpMain,'style','checkbox','units','pixels',...
            'string','debug mode','callback',@cDebugCB,...
            'Position',[10 200 150 20],'backgroundcolor','w',...
            'Value',doDebug);
        
        % Callback for editing debug mode
        function cDebugCB(cb,~)
           if cb.Value
               doDebug=1;
           else
               doDebug=0;
           end
        end
        
        %%%%%%%%%%%%%%%%%%%% Triggered settings panel %%%%%%%%%%%%%%%%%%%%%%
        hpTrig=uipanel(hFSet,'units','pixels','title','trigger settings',...
            'position',[270 10 320 140],'backgroundcolor','w');        

        % Checkbox for automated fitting
%         cFitTrig=uicontrol('parent',hpTrig,'style','checkbox','string','fit?',...
%             'units','pixels','position',[220 10 50 20],...
%             'backgroundcolor','w');
        
        % Radio button group for operation mode
        bgTrig = uibuttongroup('parent',hpTrig,'units','pixels','backgroundcolor','w',...
            'position',[10 10 160 80],'SelectionChangedFcn',@chTrigMode,...
            'Title','Trigger Mode');
        % Create three radio buttons in the button group.
        a=uicontrol(bgTrig,'Style','radiobutton','String','image only',...
            'Position',[0 0 160 20],'units','pixels',...
            'backgroundcolor','w','UserData',0);
        b=uicontrol(bgTrig,'Style','radiobutton','String','background then image',...
            'Position',[0 20 160 20],'units','pixels',...
            'backgroundcolor','w','UserData',1);
        c=uicontrol(bgTrig,'Style','radiobutton','String','image then background',...
            'Position',[0 40 160 20],'units','pixels',...
            'backgroundcolor','w','UserData',2);  
        
        switch trig.Mode
            case 0
                a.Value=1;
            case 1
                b.Value=1;
            case 2
                c.Value=1;
        end
        
        function chTrigMode(~,b)
            disp(['Changing triggered mode to ' b.NewValue.String]);
            trig.Mode=b.NewValue.UserData;           
        end
        
        uicontrol('parent',hpTrig,'style','pushbutton','string','Clear Trigger Buffer',...
            'units','pixels','position',[10 100 120 20],...
            'callback',@trigResetCB);   
        
        function trigResetCB(~,~)
            disp('Clearing stored image buffer.');
            trig.NumbImages=0;
            trig.Images={};
        end
        
        %%%%%%%%%%%%%%%%%%%% Live mode settings panel %%%%%%%%%%%%%%%%%%%%%%
        hpLive=uipanel(hFSet,'units','pixels','title','Live Mode Settings',...
            'position',[270 150 320 140],'backgroundcolor','w');  
        
        % Pushbutton for viewing the live number of counts
        uicontrol('parent',hpLive,'style','pushbutton','string',...
            'open live counts','units',...
            'pixels','position',[10 10 100 20],'Callback',@bPDCB);
        
        % Checkbox for auto background search
        uicontrol('parent',hpLive,'style','checkbox','units','pixels',...
            'string','auto-background search','callback',@cBkgdCB,...
            'Position',[10 30 150 20],'backgroundcolor','w',...
            'value',live.AutoBackground);
        
        % Checkbox for subtracting the background
        cSubLive=uicontrol('parent',hpLive,'style','checkbox','units','pixels',...
            'string','background subtract','position',[10 50 150 20],...
            'backgroundcolor','w','callback',@cSubCB,...
            'Value',live.BackgroundSubtract);
        
        % Checkbox for automated fitting
        cFitLive=uicontrol('parent',hpLive,'style','checkbox','string','fit?',...
            'units','pixels','position',[10 70 50 20],'Callback',@cFitCB,...
            'backgroundcolor','w','Value',live.Fit);
        
        % Callback for check box on background subtract
        function cSubCB(cb,~)
            if cb.Value
                live.BackgroundSubtract=true;
            else
                live.BackgroundSubtract=false;
            end
        end
        
        % Callback for check box on auto background search
        function cBkgdCB(cb,~)
            if cb.Value
                live.AutoBackground=true;
                imgBG=1024*ones(5000,5000);
                live.BackgroundSubtract=false;
                set(cSubLive,'Value',0,'Enable','off');
                set(cFitLive,'value',0,'enable','off');
            else
                live.AutoBackground=false;
                set(cSubLive,'Enable','on');
                set(cFitLive,'enable','on');
            end
        end

        % Callback for check box on engaging the fit
        function cFitCB(cb,~)
            if cb.Value
                live.Fit=true;
                pRet.Visible='on';
                textFit.Visible='on';
            else
                live.Fit=false;
                pRet.Visible='off';
                textFit.Visible='off';
            end
        end   

        function bPDCB(~,~)
           hFPD=figure('Name','photodiode','toolbar','none','menubar','none');
           hFPD.Color='w';
           axes;
           pp=plot(0,0);
           xlabel('time (s)');
           ylabel('counts');
           set(gca,'FontSize',14);       
           uicontrol('style','pushbutton','string','clear data',...
               'units','pixels','position',[0 0 70 20],'callback',@bResetCB);       
            function bResetCB(~,~)
               T=[];
               Y=[];
               t0=now;
               cBGs=[];
            end       
        end

        function chROI(tbl,~)
            disp(['Changing the hardware ROI. This needs to stop the ' ...
                'camera and the software timer.']);
            stop(timerLive);
            pause(0.5);
            newROI=tbl.Data;     
            setROI(newROI);          
            set(hImg,'XData',xVec,'YData',yVec,'CData',...
                zeros(length(yVec),length(xVec)));
            start(timerLive);
        end
                
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
                        gVal=cam.ConvertDecibelsToGain(val);
                        cam.Gain=gVal;                        
                        gGain=cam.ConvertGainToDecibels(cam.Gain);
                        tbl.Data(data.Indices)=gGain;                        
                        textGain.String=[num2str(gGain) ' dB'];
                    else
                        tbl.Data(data.Indices)=data.PreviousData;                        
                    end            
                case 2
                    if val>=64 && val<=1E5
                        val=round(val);
                        disp(['Changing exposure to ' num2str(val) ' us']);
                        cam.ExposureTime_us=uint32(val);
                        tbl.Data(r)=double(cam.ExposureTime_us);
                        tExp=tbl.Data(r);
                        textExp.String=[num2str(tExp) ' \mus'];                        
                    else
                        tbl.Data(r)=data.PreviousData;                        
                    end
            end          
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


%% Functions

% Callback function for checking if the camera was triggered
    function trigCB(~,~)
        if doDebug       
            pause(5);
            img1=grabImage;            
            trig.Images{1}=img1;
            hImg.CData=img1;
            trig.NumImages=1;
            drawnow;
            disp('trig detected');
            pause(2)
            img2=grabImage;
            trig.Images{2}=img2;
            hImg.CData=img2;
            trig.NumImages=2;
            drawnow;
            disp('trig detected');
            stop(timerTrig);
            processTriggeredImages;
            start(timerTrig);
            return
        end
        
        
        if cam.NumberOfQueuedFrames
            disp('Trigger detected!');            
            img=grabImage;
            switch trig.NumImages
                case 0
                    trig.Images{1}=img;
                    trig.NumImages=1;
                case 1
                    trig.Images{2}=img;
                    processTriggeredImages;
                    trig.NumImages=0;
                    trig.Images={};
                otherwise
                    disp('hinonono');
                    % Clear triggered data
                    trig.NumImages=0;
                    trig.Images={};
            end
        end
        
        
    end

% Process the triggered images
    function processTriggeredImages     
        % Create new analysis figure
        str=[hF.Name ' - Analysis'];
        hFA=figure(hF.Number+1);
        set(hFA,'color','w','units','pixels','Name',str,...
           'MenuBar','none','toolbar','none');
        clf

        % Show the first image 
        ax1=subplot(221,'parent',hFA);
        imagesc(ax1,xVec,yVec,trig.Images{1});
        title('image 1');
        axis equal tight

        % Show the second image
        ax2=subplot(223,'parent',hFA);
        imagesc(ax2,xVec,yVec,trig.Images{2});
        title('image 2');
        axis equal tight
        % The data is the difference of the two images
        if trig.Mode==1
           data=trig.Images{2}-trig.Images{1};
        else
           data=trig.Images{1}-trig.Images{2};
        end          
        
        % Show the data
        ax3=subplot(222,'parent',hFA);
        imagesc(ax3,xVec,yVec,data);
            axis equal tight

        hold on

        % Perform the fit
        fout=gaussfit2D(xVec,yVec,data);

        % Process the coefficient values
        cvals=coeffvalues(fout);
        
        str=['cen : (' num2str(round(cvals(2))) ',' ...
        num2str(round(cvals(4))) '), \sigma : (' ...
        num2str(round(cvals(3))) ',' num2str(round(cvals(5))) ')'];
        disp(cvals);
        % Text summary
        text(2,2,str,'color','r','units','pixels',...
            'verticalalignment','bottom','Fontsize',14);

        % Plot the reticle for gauss 1/e^2
        tVec=linspace(0,2*pi,200);                   
        xvec=cvals(2)+2*cvals(3)*cos(tVec);
        yvec=cvals(4)+2*cvals(5)*sin(tVec);      
        plot(ax3,xvec,yvec,'r-','linewidth',1)
        title('data');

        % Create summed profiles of the dawta
        Xdata=sum(data,1);
        Ydata=sum(data,2);

        % Create summed profile for the fit
        [xx,yy]=meshgrid(xVec,yVec);
        fitData=feval(fout,xx,yy);
        Xfit=sum(fitData,1);
        Yfit=sum(fitData,2);

        % Plot the x summed profile
        axx=subplot(426,'parent',hFA);       
        plot(axx,xVec,Xdata)
        hold on
        plot(axx,xVec,Xfit,'r-');
        xlabel('x pixels');
        ylabel('summed counts x');

        % Plot the y summed profile
        axy=subplot(428,'parent',hFA);
        plot(axy,yVec,Ydata)
        hold on
        plot(axy,yVec,Yfit,'r-');
        xlabel('y pixels');
        ylabel('summed counts y');

        %% Output parameters
        %Read the output paramaeter from the file
        opt_param =1;
        outfilename = 'Y:\_communication\control.txt';
        disp(['Opening information from from ' outfilename]);
        
        %open the file
        fid = fopen(outfilename,'rt');
        if fid==-1 %no file found
            disp('no output file found');
            opt_param = -100;
        else
            %do a custom input of the first six lines
            for i = 1:4
                fgetl(fid);
            end
            cyclestr = fgetl(fid);
            cycle = str2double(cyclestr(8:end));
            fgetl(fid);
            %now use textscan for the rest of the file
            C = textscan(fid,'%[^:] %*s %s');
            opt_params = C;
            %close the file
            fclose(fid);    
            %for now just return the scan parameters
            if isempty(opt_params{2})
                opt_param = -100;        
            else                
                %paramnames = opt_params{1};
                paramvals = opt_params{2};
                disp(paramvals)
                opt_param = str2double(paramvals(3));
            end
        end
        
        %save good data 
        save_data = 0;
        if (save_data)
        dir = 'Y:\Data\2020\2020.09\24 September 2020\F_D1Molasees_TOF__molasses_time_6ms_detuning_20MHz_AOM_pwr_1.2Vpp_2phdet_-0.6MHz_SRS_6dBM_shimXYZ_15_15_00_MOT_coil_-0.5ms_Cam10148';
        save(fullfile(dir,['mol_exp_wait_',num2str(opt_param),'_',datestr(now,'HHMMss'),'.mat']),'data');
        end
        
        cvals = [opt_param, cvals];
        
        a=['results(end+1,:)=[' num2str(cvals) '];'];
        evalin('base',a)

        %% Clear triggered data
        trig.NumImages=0;
        trig.Images={};
    end

% Callback function for live update
    function liveCB(~,~)
        cam.IssueSoftwareTrigger;        
        pause(0.05);
        updateImage;
    end

% Grab the image camera if available
    function img=grabImage
        img=[];
        imageFrame = cam.GetPendingFrameOrNull;
        if ~isempty(imageFrame)
            imageData = imageFrame.ImageData.ImageData_monoOrBGR;
            imageHeight = imageFrame.ImageData.Height_pixels;
            imageWidth = imageFrame.ImageData.Width_pixels;   
            img = reshape(uint16(imageData), [imageWidth, imageHeight]);  
            img = img';
            if isequal(sn,'10148')
                img = imrotate(img,180);       
            end
        end
        
        if doDebug && isequal(cameraMode,'Live')
           a=datevec(now);
           a=a(6);           
           t=mod(a,8);
           N0=800*(1+rand*.05)*(1-exp(-t/2));  
           xC=mean(xVec)+rand*10;
           yC=mean(yVec)+rand*10;     
           yS=100*(1+rand*.05);
           xS=200*(1+rand*.05);
           [xx,yy]=meshgrid(xVec,yVec);           
           foo=@(x,y) N0*exp(-(x-xC).^2/(2*xS^2)).*exp(-(y-yC).^2/(2*yS^2));
           data=foo(xx,yy);          
           noise=50*rand(length(yVec),length(xVec));           
           img=data+noise;             
        end
          
        if doDebug && isequal(cameraMode,'Triggered')
            N0=400*(1+rand*.05);  
            xC=mean(xVec)+rand*10;
            yC=mean(yVec)+rand*10;     
            yS=100*(1+rand*.05);
            xS=200*(1+rand*.05);
            [xx,yy]=meshgrid(xVec,yVec);           
            foo=@(x,y) N0*exp(-(x-xC).^2/(2*xS^2)).*exp(-(y-yC).^2/(2*yS^2));
            data=foo(xx,yy);          
            noise=300*rand(length(yVec),length(xVec));  
            switch trig.Mode
                case 0
                    img=data;
                case 1
                    if trig.NumImages==0
                       img=noise;
                    else
                        img=data+noise;
                    end
                case 2
                    if trig.NumImages==0
                       img=data+noise;
                    else
                        img=noise;
                    end                    
            end      
        end
    end

    function updateImage   
        % Grab the image
        img=grabImage;
        
        % Exit if no image to be had
        if isempty(img)
            return
        end
           
        % Subtract the background image
        if live.BackgroundSubtract
            hImg.CData=img-imgBG;
        else  
            hImg.CData=img;  
        end
        
        c=sum(sum(img));  
        textCounts.String=sprintf('%.4e',c);              


        if live.Fit
            if live.BackgroundSubtract
                data=img-imgBG;
            else
                data=img;
            end
            
           fout=gaussfit2D(xVec,yVec,data);
           cvals=coeffvalues(fout);
           cvals(2:5)=cvals(2:5);
           textFit.String=['cen : (' num2str(round(cvals(2))) ',' ...
               num2str(round(cvals(4))) '), \sigma : (' ...
               num2str(round(cvals(3))) ',' num2str(round(cvals(5))) ')'];
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

        if live.AutoBackground                            
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
     
    end

%% Camera Functions

% Open camera with a given serial number, default to software trigger
    function tlCamera=openCamera(SN)     
        disp(['Opening camera ' SN]);
        tlCamera = tlCameraSDK.OpenCamera(SN, false);        
        % Get and Set camera parameters
        tlCamera.ExposureTime_us = uint32(tExp);        
        % The default black level should be zero
        tlCamera.BlackLevel=uint32(0);       
        % Set the default gain level to zero
        tlCamera.Gain=tlCamera.ConvertDecibelsToGain(uint32(gGain));                
        % Set operation mode to software testing
        tlCamera.OperationMode = ...
            Thorlabs.TSI.TLCameraInterfaces.OperationMode.SoftwareTriggered;    
        % Set frames per trigger to one
        tlCamera.FramesPerTrigger_zeroForUnlimited = 1;            
        % Set default ROI to max
        tlCamera.ROIAndBin.ROIHeight_pixels=tlCamera.SensorHeight_pixels;
        tlCamera.ROIAndBin.ROIWidth_pixels=tlCamera.SensorWidth_pixels;
        % Set the trigger polarity to high
        tlCamera.TriggerPolarity=...
            Thorlabs.TSI.TLCameraInterfaces.TriggerPolarity.ActiveHigh; 
        % Turn LED Off (it can add background signal)
        tlCamera.IsLEDOn=0;      
        % Arm the camera
        tlCamera.Arm;        
    end

% Close the camera
    function closeCamera(tlCamera)
        disp('Closing camera');
        if (tlCamera.IsArmed)
            tlCamera.Disarm;
        end
        tlCamera.Dispose;        
        delete(tlCamera);           
    end

% Read the hardware ROI on the camera
    function [ROI,X,Y]=readROI
       % Read the X ROI
        x1=cam.ROIAndBin.ROIOriginX_pixels;
        W=cam.ROIAndBin.ROIWidth_pixels;
        
        % Read the Y ROI
        y1=cam.ROIAndBin.ROIOriginY_pixels;
        H=cam.ROIAndBin.ROIHeight_pixels;    
        
        % Read the total sensor size
        H0=cam.SensorHeight_pixels;
        W0=cam.SensorWidth_pixels;    
        
        % Redefine the ROI for a camera that is flipped
        if  isequal(sn,'10148')
            x1=W0-W+x1;
            y1=H0-H+y1;
        end   
        
        % Final processing on ROI
        ROI=double([x1+1 W+x1 y1+1 y1+H]);     
        
        % Output a pixel position vector for simplicity
        X=ROI(1):ROI(2);
        Y=ROI(3):ROI(4);
    end

% Set the hardware ROI
    function setROI(newROI)
        % Read the current Region of Interest (ROI)
        H0=cam.SensorHeight_pixels;
        W0=cam.SensorWidth_pixels;
        
        % Calculate the new widths
        W=newROI(2)-newROI(1)+1;
        H=newROI(4)-newROI(3)+1;
        
        % Get the new origins
        x1=newROI(1)-1;
        y1=newROI(3)-1;        
        
        % Change the speciifications if using rotated camera
        if isequal(sn,'10148')
            x1=W0-newROI(2);
            y1=H0-newROI(4);
        end       
        
       % Arm the camera
        cam.Disarm;        
                
        % Set the ROI height and width
        cam.ROIAndBin.ROIHeight_pixels=uint32(H);
        cam.ROIAndBin.ROIWidth_pixels=uint32(W);
        
        % Set the ROI origin
        cam.ROIAndBin.ROIOriginX_pixels=x1;
        cam.ROIAndBin.ROIOriginY_pixels=y1;
        
        % Read the ROI to verify
        [ROI,xVec,yVec]=readROI;      
        
        % Arm the camera
        cam.Arm;
    end
end

  
function fout=gaussfit2D(Dx,Dy,data)
% Make and X and Y pixel vectors

data=double(data);              % data is double and not uint32 
data=imresize(data,0.25);
Dx=imresize(Dx,.25);
Dy=imresize(Dy,.25);


dSmooth=imgaussfilt(data,15);   % Smooth data
N0=max(max(dSmooth));           % Extract peak

% Get rid of noise
Z=dSmooth;
Z(dSmooth<N0*.5)=0;



% Get the profiles
X=sum(Z,1);
Y=sum(Z,2)';

% Get the total number of counts
Nx=sum(X);
Ny=sum(Y);

% Find the Center
Xc=mean(Dx(X>.9*max(X)));
Yc=mean(Dy(Y>.9*max(Y)));

% Calculate sigma in X and Y
Xs=1.5*sqrt(sum((Dx-Xc).^2.*X)/Nx);
Ys=1.5*sqrt(sum((Dy-Yc).^2.*Y)/Ny);

% Make a mesh grid for fitting
[xx,yy]=meshgrid(Dx,Dy);

% Make an initial guess
Zguess=N0*exp(-(xx-Xc).^2./(2*Xs)^2).*exp(-(yy-Yc).^2./(2*Ys)^2);

% Copy the data
data2=data;
xx2=xx;
yy2=yy;

% Elminate data points below a threshold to reduce fitting space
xx2(Zguess<.15*N0)=[];
yy2(Zguess<.15*N0)=[];
data2(Zguess<.15*N0)=[];

% Calculate the appropriate background
bg=sum(sum(data-Zguess))/(length(X)*length(Y));

% Create fit object
myfit=fittype('N0*exp(-(xx-Xc).^2./(2*Xs)^2).*exp(-(yy-Yc).^2./(2*Ys)^2)+cc',...
    'independent',{'xx','yy'},'coefficients',{'N0','Xc','Xs','Yc','Ys','cc'});
opt=fitoptions(myfit);
opt.StartPoint=[N0 Xc Xs Yc Ys bg];
opt.Lower=[N0/10 10 1 10 1 0];
opt.Upper=[5*N0 max(X) range(X) max(Y) range(Y) N0];

opt.Weights=[];

% Perform the fit
[fout,gof,output]=fit([xx2(:) yy2(:)],data2(:),myfit,opt);


end

