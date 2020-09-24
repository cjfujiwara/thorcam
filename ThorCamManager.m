function ThorCamManager
% ThorCamManager.m
%
%   Author      : CJ Fujiwara
%   Last Edited : 2020/08/28
% This is the software to run the Thor Labs CS MU165 cameras.  They are
% CMOS monochromatic cameras with a 10-bit ADC. Their primary purpose is
% to be used as fluorescence imaging cameras in the MOT chamber for the
% lattice experiment.
%
% This particular file, ThorCamManager.m is meant to manage multiple
% instances of the camera.  It's primary role is to load the software
% development kit (SDK) and manage connections to the camers.
%
% This software is designed using the ThorLabsCamerGUI.m,
% HardwareTrigger.m, and SoftwareTrigger.m example software provided by
% Thorlabs which allow for interfacing with the cameras using MATLAB over
% the NET assembly framework. This framework should in principle work with
% other ThorLabs cameras, but this code is designed specifically for these
% cameras.
%
% Experimentally, there are two cameras with serial numbers 10118 and 10148
% which are co-axial with the horizontal MOT beams. The 10118 camera is
% called the "X" camera and the 10148 camera is called the "Y" camera.
%
% There are two predominant modes of operating this software (1) Triggered
% and (2) Live modes.  The live mode is meant to provided qualitative real
% time analysis of the fluorescence from the MOT. The triggered mode is
% triggered from the AdWin control software using a digital channel to the
% trigger input of the camera.
%
% In the triggered mode, the results of the image analysis will be exported
% to the primary MATLAB workspace, but this has not been implemented yet.


% The two cameras that we connect to for fluorescence analysis are:
% 10118 - X CAMERA
% 10148 - Y CAMERA

% List of all camera objects
allCams={};


%% Load Libraries to run the camera

% Add the directory which holds this folder to the MATLAB path
addpath(fileparts(mfilename('fullpath')));


% Load TLCamera DotNet assembly.
% Directory where the dlls are located, this could depend on your comptuer
str='C:\Users\Solaire\Downloads\Thorlabcam\Scientific Camera Interfaces\MATLAB';

% Change directory to where stored the dlls
cd(str);
str=[pwd filesep 'Thorlabs.TSI.TLCamera.dll'];

% Check is the DLL's exist
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


%% Graphical interface

% Initialize the figure
hF=figure(1235);
set(hF,'color','w','Name','ThorCam Interface','NumberTitle','off',...
    'MenuBar','none','toolbar','none','units','pixels',...
    'CloseRequestFcn',@closeCB,'resize','off');
hF.Position(3:4)=[500 30];

% Load the available cameras
refreshCameras;

% Callback for when the figure is requested to close
   function closeCB(fig,~)       
        fprintf('Closing the camera SDK...');   % Message the user
        tlCameraSDK.Dispose;                    % Unload the SDK
        disp('done');    
        delete(fig)                             % Delete the figure
   end

% Refresh the detected cameras connected to this computer
    function refreshCameras(~,~)    
        fprintf('Refreshing connected cameras ... ');
        
        % Remove old camera menu
        set(hF,'MenuBar','none');
        nDel=[];
        for n=1:length(hF.Children)
            if isequal(class(hF.Children(n)),'matlab.ui.container.Menu')
               nDel(end+1)=n;
            end
        end        
        delete(hF.Children(nDel))

        % Add the cameras and refresh menu 
        m=uimenu('text','camera'); 
        uimenu(m,'Text','Refresh','callback',@refreshCameras);

        % Grab serial numbers of the available cameras
        SNs=tlCameraSDK.DiscoverAvailableCameras;
        
        % Add each camera to the list
        for ii = 1:SNs.Count
            camName=char(SNs.Item(ii-1));   
            allCams{ii} =camName;                
            ms{ii}=uimenu(m,'Text',camName,'UserData',camName,...
                'callback',@selCamera);    
        end 
        disp('done');
    end

% Callback funciton for when a menu item is selected
    function selCamera(men,~)
        switch men.Checked
            case 'on'
                % Turn the camera off
                disp(['Turning off camera ' men.Text]) 
                men.Checked='off';
            case 'off'
                % Turn the camera on
                disp(['Turning on camera ' men.Text])   
                men.Checked='on';
                fig=openCam(men.Text,tlCameraSDK);
        end    
    end
end


