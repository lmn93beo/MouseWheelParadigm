function fnParadigmMouseWheelCycleNew(strctInputs)
%
% Copyright (c) 2008 Shay Ohayon, California Institute of Technology.
% This file is a part of a free software. you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation (see GPL.txt)

global g_strctParadigm g_strctPTB

fCurrTime = GetSecs;

if isempty(g_strctParadigm.m_strctCurrentTrial) && g_strctParadigm.m_iMachineState > 2
    g_strctParadigm.m_iMachineState = 2;
end

%% Cases
switch g_strctParadigm.m_iMachineState
    case 0
        fnParadigmToKofikoComm('SetParadigmState','Waiting for user to press Start');

    case 1 % Run some tests that everything is OK. Then goto 2
        if g_strctParadigm.m_iNumStimuli > 0
            g_strctParadigm.m_iMachineState = 2;
        else
            fnParadigmToKofikoComm('SetParadigmState','Cannot start machine. Please load an image list.');
        end;
    case 2
%         if isempty(g_strctParadigm.m_strctDesign)
%             g_strctParadigm.m_iMachineState = 1;
%             return;
%         end;
%         % Set Next "trial" (image on->off)
%          if g_strctParadigm.m_bRepeatNonFixatedImages && ~g_strctParadigm.m_bJustLoaded && ...
%                  ~isempty(g_strctParadigm.m_strctCurrentTrial) && isfield(g_strctParadigm.m_strctCurrentTrial,'m_bMonkeyFixated') &&  ~g_strctParadigm.m_strctCurrentTrial.m_bMonkeyFixated
%              % Keep same trial....
%          else
             % This is the important call to set up all the different
             % parameters for the next trial (media, position, etc...)
       % fWheelVoltage= fnDAQ('GetAnalog', g_strctDAQParams.m_fConveyerPort);
       % fnTsSetVarParadigm('WheelVoltage',fWheelVoltage);
            g_strctParadigm.m_strctCurrentTrial = fnMouseWheelPrepareTrial();
            
%          end
         
% JCL 9/20/13 - to speed up case 2
%          if g_strctParadigm.m_bJustLoaded
%              g_strctParadigm.m_bJustLoaded = false;
%          end;
         
       
        g_strctParadigm.m_bStimulusDisplayed = true;
        
        g_strctParadigm.m_bGivenJuiceperTrial = false;
        fnParadigmToStatServerComm('Send','TrialStart');
        fnDAQWrapper('StrobeWord', g_strctParadigm.m_strctStatServerDesign.TrialStartCode);   
        
        % SO 21 Sep 2011
        % Very important
        % This will tell the statistics server which trial type is
        % starting by sending a strobe word to plexon....
        fnParadigmToKofikoComm('TrialStart',g_strctParadigm.m_strctCurrentTrial.m_iStimulusIndex);  
        
        % Instruct the stimulus server to display the trial....
        fnParadigmToStimulusServer('ShowTrial',g_strctParadigm.m_strctCurrentTrial);
        g_strctParadigm.m_strctCurrentTrial.m_fSentMessageTimer = GetSecs();
        
% JCL 9/20/13 - to speed up case 2          
%         iSelectedBlock = g_strctParadigm.m_strctDesign.m_strctBlocksAndOrder.m_astrctBlockOrder(g_strctParadigm.m_iCurrentOrder).m_aiBlockIndexOrder(g_strctParadigm.m_iCurrentBlockIndexInOrderList);
%         iNumMediaInBlock = length(g_strctParadigm.m_strctDesign.m_strctBlocksAndOrder.m_astrctBlocks(iSelectedBlock).m_aiMedia);
% 
%         strBlockName =  g_strctParadigm.m_strctDesign.m_strctBlocksAndOrder.m_astrctBlocks(iSelectedBlock).m_strBlockName;
%         iNumBlocks = length(g_strctParadigm.m_strctDesign.m_strctBlocksAndOrder.m_astrctBlockOrder(g_strctParadigm.m_iCurrentOrder).m_aiBlockIndexOrder);
%         iNumTimesToShowBlock = g_strctParadigm.m_strctDesign.m_strctBlocksAndOrder.m_astrctBlockOrder(g_strctParadigm.m_iCurrentOrder).m_aiBlockRepitition(g_strctParadigm.m_iCurrentBlockIndexInOrderList);
%         
%         
%         fnParadigmToKofikoComm('SetParadigmState', sprintf('Block %d/%d (%s), Block Rep %d/%d, Image %d (%d/%d)', ...
%             g_strctParadigm.m_iCurrentBlockIndexInOrderList,...
%             iNumBlocks,...
%             strBlockName,...
%             g_strctParadigm.m_iNumTimesBlockShown,...
%             iNumTimesToShowBlock,...
%             g_strctParadigm.m_strctCurrentTrial.m_iStimulusIndex,...
%             g_strctParadigm.m_iCurrentMediaIndexInBlockList,...
%             iNumMediaInBlock));
        g_strctParadigm.m_iMachineState = 3;
        
    case 3
        % Wait for message that trial started (i.e., image was displayed on
        % screen)
        if ~isempty(strctInputs.m_acInputFromStimulusServer) 
            if strcmpi(strctInputs.m_acInputFromStimulusServer{1},'FlipON')
                % Get time when stimulus goes on
                g_strctParadigm.m_strctCurrentTrial.m_fImageFlipON_TS_StimulusServer = strctInputs.m_acInputFromStimulusServer{2};
                g_strctParadigm.m_strctCurrentTrial.m_fImageFlipON_TS_Kofiko = GetSecs();
           
                fnParadigmToStatServerComm('Send','TrialAlign');
                fnDAQWrapper('StrobeWord', g_strctParadigm.m_strctStatServerDesign.TrialAlignCode);
               
                % Now, it depends if we switch stimulus off or not.
                % No OFF - period. Server is not going to send another
                % message
                g_strctParadigm.m_strctCurrentTrial.m_fImageFlipOFF_TS_StimulusServer = g_strctParadigm.m_strctCurrentTrial.m_fImageFlipON_TS_StimulusServer;
                g_strctParadigm.m_iMachineState = 5;
                 
            end
        else
            % Message back should have arrive within 1 refresh rate
            % interval. We use 1 second, just to be sure.
            if fCurrTime-g_strctParadigm.m_strctCurrentTrial.m_fSentMessageTimer > 1
                fnParadigmToKofikoComm('DisplayMessage','Missed FlipON Event');
                g_strctParadigm.m_iMachineState = 1;
                

                fnParadigmToStatServerComm('Send',['TrialOutcome ',num2str(g_strctParadigm.m_strctStatServerDesign.TrialOutcomesCodes(1))]);
                fnParadigmToStatServerComm('Send','TrialEnd');
                
                fnDAQWrapper('StrobeWord', g_strctParadigm.m_strctStatServerDesign.TrialOutcomesCodes(1));
                fnDAQWrapper('StrobeWord', g_strctParadigm.m_strctStatServerDesign.TrialEndCode);
                    
                
            end
        end

       
    case 5
        % We are not in the "OFF" Period. Wait until trial is over              
        %if ~isempty(strctInputs.m_acInputFromStimulusServer) && strcmp(strctInputs.m_acInputFromStimulusServer{1},'TrialFinished')           
            iNumFramesDisplayed = 1;
            fnParadigmToKofikoComm('TrialEnd', true);  %Successful trial always
            
%    
%             fnDAQWrapper('StrobeWord', g_strctParadigm.m_strctStatServerDesign.TrialOutcomesCodes(3));
%             
           %Assuming fixated
           fnParadigmToStatServerComm('Send',['TrialOutcome ',num2str(g_strctParadigm.m_strctStatServerDesign.TrialOutcomesCodes(3))]);
           fnDAQWrapper('StrobeWord', g_strctParadigm.m_strctStatServerDesign.TrialOutcomesCodes(3));    
           fnParadigmToStatServerComm('Send','TrialEnd');
           fnDAQWrapper('StrobeWord', g_strctParadigm.m_strctStatServerDesign.TrialEndCode);            
            
               
            
            % Store only the relevant stuff. The other parameters can be
            % recovered later.
            aiTrialStoreInfo = [g_strctParadigm.m_strctCurrentTrial.m_iStimulusIndex,...
                                g_strctParadigm.m_strctCurrentTrial.m_fImageFlipON_TS_StimulusServer,... 
                                g_strctParadigm.m_strctCurrentTrial.m_fImageFlipOFF_TS_StimulusServer,... 
                                g_strctParadigm.m_strctCurrentTrial.m_fSentMessageTimer,... 
                                g_strctParadigm.m_strctCurrentTrial.m_fImageFlipON_TS_Kofiko,...
                                g_strctParadigm.m_strctCurrentTrial.m_fWheelVoltage,...
                                g_strctParadigm.m_strctCurrentTrial.m_fStimulusON_MS,...
                                iNumFramesDisplayed]';
             
            fnTsSetVarParadigm('Trials',aiTrialStoreInfo);
            
            % Prepare next trial
            g_strctParadigm.m_iMachineState = 2;  
       
%         else
%             %Fixed threshold for timeout trials
%                             fprintf('5 else\n');
% 
%             if fCurrTime-g_strctParadigm.m_strctCurrentTrial.m_fImageFlipON_TS_Kofiko > 3 * (g_strctParadigm.m_strctCurrentTrial.m_fStimulusON_MS/1e3)
%                 fnParadigmToKofikoComm('DisplayMessage','Missed Trial End Event');
%                 
%                 fnParadigmToStatServerComm('Send',['TrialOutcome ',num2str(g_strctParadigm.m_strctStatServerDesign.TrialOutcomesCodes(1))]);
%                 fnParadigmToStatServerComm('Send','TrialEnd');
%   
%                 fnDAQWrapper('StrobeWord', g_strctParadigm.m_strctStatServerDesign.TrialOutcomesCodes(1));
%                 fnDAQWrapper('StrobeWord', g_strctParadigm.m_strctStatServerDesign.TrialEndCode);                
%                 
%                 g_strctParadigm.m_iMachineState = 1;
%             end
%         end;
%         %read next voltage      moved to case 2 instead 
%         fWheelVoltage= fnDAQWrapper('GetAnalog', g_strctDAQParams.m_fConveyerPort);
%         fprintf('%d\n', fWheelVoltage);
%         fnTsSetVarParadigm('WheelVoltage',fWheelVoltage);
%
        
    case 6
        % Monkey is not looking
        % Wait until he is looking and then start a new trial...
        g_strctParadigm.m_iMachineState = 1;
        
 end;
%% Mouse related activity 
% These events cannot be handled by the callback function since the mouse
% events are not registered as matlab events.
if g_strctParadigm.m_bUpdateStimulusPos && strctInputs.m_abMouseButtons(1) && strctInputs.m_bMouseInPTB
    % Don't mind using the slow fnTsSetVar here because it is a rare event
    fnTsSetVarParadigm('StimulusPos',1/g_strctPTB.m_fScale * strctInputs.m_pt2iMouse);
    fnDAQWrapper('StrobeWord', fnFindCode('Stimulus Position Changed'));                
end;

%% Reward related stuff
%global g_strctParadigm
if g_strctParadigm.m_iMachineState == 0
    return;
end


% Give Juice!
% fnParadigmToKofikoComm('DisplayMessage', sprintf('Juice Time = %.2f ,Gaze Time = %.1f',fJuiceTimeMS,fGazeTimeSec*1e3 ) );
if ~isempty(g_strctParadigm.m_strctCurrentTrial)
    %Moved up here from first if statement JCL 9/24/13
   aiScreenSize = fnParadigmToKofikoComm('GetStimulusServerScreenSize');  
   WaitTime = g_strctParadigm.WaitTime.Buffer(1,:,g_strctParadigm.WaitTime.BufferIdx);
   pt2fStimulusPos =g_strctParadigm.m_strctCurrentTrial.m_pt2fStimulusPos;
   fTargetPosRange = g_strctParadigm.TargetPosRange.Buffer(1,:,g_strctParadigm.TargetPosRange.BufferIdx);
   fStimulusSizePix =g_strctParadigm.m_strctCurrentTrial.m_fStimulusSizePix;
   hTexturePointer = g_strctParadigm.m_strctDesign.m_astrctMedia(g_strctParadigm.m_strctCurrentTrial.m_iStimulusIndex).m_aiMediaToHandleIndexInBuffer(1);
   aiTextureSize = g_strctParadigm.m_strctTexturesBuffer.m_a2iTextureSize(:,hTexturePointer)';
   aiStimulusRect = g_strctPTB.m_fScale * fnComputeStimulusRect(fStimulusSizePix, aiTextureSize, pt2fStimulusPos);
   
StopTime = g_strctParadigm.StopTime.Buffer(1,:,g_strctParadigm.StopTime.BufferIdx);
% StimulusWidth = g_strctParadigm.m_strctCurrentTrial.m_pt2fStimulusPos(3)-g_strctParadigm.m_strctCurrentTrial.m_pt2fStimulusPos(1);


if ismember('target', lower(g_strctParadigm.m_strctCurrentTrial.m_strctMedia.m_acAttributes))
%    if ~g_strctParadigm.m_strctCurrentTrial.m_bGivenJuice && ...
%        abs(g_strctParadigm.m_strctCurrentTrial.m_fVoltageDiff) < fTargetVoltageDiffRange && ...
%        abs(g_strctParadigm.m_strctCurrentTrial.m_pt2fStimulusPos(1)-aiScreenSize(3)/2) < fTargetPosRange && ~g_strctParadigm.m_bGivenJuiceperTrial
%        fJuiceTimeMS = g_strctParadigm.JuiceTimeMS.Buffer(g_strctParadigm.JuiceTimeMS.BufferIdx);
      if ~g_strctParadigm.m_strctCurrentTrial.m_bGivenJuice && ...
              StopTime > WaitTime && ...
              aiStimulusRect(3)-aiScreenSize(3)/2 < fTargetPosRange && ...
              aiStimulusRect(1)-aiScreenSize(3)/2 > -fTargetPosRange && ...
              ~g_strctParadigm.m_bGivenJuiceperTrial
          % JUICE
          fJuiceTimeMS = g_strctParadigm.JuiceTimeMS.Buffer(g_strctParadigm.JuiceTimeMS.BufferIdx);
          fnParadigmToKofikoComm('newjuice', fJuiceTimeMS);

          strctTrial.m_bGivenJuice = true;
          g_strctParadigm.m_bGivenJuiceperTrial = true;
          fnTsSetVarParadigm('GivenJuice',strctTrial.m_bGivenJuice);
          fnTsSetVarParadigm('CorrectStop',g_strctParadigm.m_strctCurrentTrial.m_iStimulusIndex);
      end
elseif ~g_strctParadigm.m_strctCurrentTrial.m_bGivenJuice && ...
        StopTime > WaitTime && ...
       abs(g_strctParadigm.m_strctCurrentTrial.m_pt2fStimulusPos(1)-aiScreenSize(3)/2) < fTargetPosRange && ~g_strctParadigm.m_bGivenJuiceperTrial  
   % record that the mouse stopped at the wrong shape JCL 9/24/13      
   fnTsSetVarParadigm('IncorrectStop',g_strctParadigm.m_strctCurrentTrial.m_iStimulusIndex);
   % only 1 incorrect stop marked at a time
   strctTrial.m_bGivenJuice = true;
         g_strctParadigm.m_bGivenJuiceperTrial = true;
   fnTsSetVarParadigm('GivenJuice',strctTrial.m_bGivenJuice);
end  

    
end
return;



