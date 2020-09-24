function thorCamTrig(sn,tlCameraSDK)

% Default Setting
tExp=64;                % Exposure time us
gGain=20;               % Gain in dB
ROIbg=[800 1000 1 200]; % ROI for background detection


%% Create Graphical Interface
hF=figure(str2num(sn));
set(hF,'Color','w','MenuBar','none','Toolbar','None');
hF.Name=['MOT CAMERA TRIGGER SN - ' sn];
clf
hF.CloseRequestFcn=@closeCB;

 function bSettingsCB(~,~)
        hFSet=figure('Name','Settings','Toolbar','none','menubar','none',...
            'resize','off');
        hFSet.Position(3:4)=[400 200];
        hFSet.Position(1:2)=hF.Position(1:2)+hF.Position(3:4)/2-...
            hFSet.Position(3:4)/2;
        
        % Read the camera settings
        gGain=double(cam.ConvertGainToDecibels(cam.Gain));
        tExp=double(cam.ExposureTime_us);
        
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
        
         function bSettingsCB(~,~)
        hFSet=figure('Name','Settings','Toolbar','none','menubar','none',...
            'resize','off');
        hFSet.Position(3:4)=[400 200];
        hFSet.Position(1:2)=hF.Position(1:2)+hF.Position(3:4)/2-...
            hFSet.Position(3:4)/2;
        
        % Read the camera settings
        gGain=double(cam.ConvertGainToDecibels(cam.Gain));
        tExp=double(cam.ExposureTime_us);
        
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

end

