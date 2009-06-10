//
//  XstrumentModel.m
//  Xstrument
//
/*
 The Samchillian is patented by Leon Gruenbaum. 
 I have gotten permission to make this application available for general consumption. 
 Refer to the original Samchillian 
 http://www.samchillian.com 
 if you have any questions about whether you need to be concerned about copyright
 or patent issues (such as if you have implemented something similar yourself). 
 Like the official Samchillian software, this is only for non commercial use, 
 which means that you have no right to sell this or modified copies of this 
 software without explicit permission.  
 */
/*
 The timeA/timeB pair specify a time interval that can be used for echo
 
 The tickA/tickB pair specify the last time MIDI messages were sent versus the current time.
 When determining what MIDI messages need to be sent, we iterate echoNote echoVol buffers from
 
     tickA < i <= tickB
 
 We play those notes as we iterate.  Then we zero out the notes that we have played while writing
 forward (at decreased volume and 1 interval away) any echoes we need to write.  We presume that
 the echo decreases at such a rate that a single note will never propagate all the way around the buffer.
 
 Presume for the moment that we only handle note down events.  
 */
//

#import "XstrumentModel.h"
#import "MusicTheory.h"

@implementation XstrumentModel
-(id)initNow:(uint64_t)now
{
	int buf=0;
	int i=0;
	timeA=0;
	timeB=0;
	tickA=0;
	tickB=0;
	diatonicRetranslate=0;
	chromaticRetranslate=0;
	timeCycled=now;
	timePlayed=now;

    mach_timebase_info(&timebaseInfo);
		
	chromaticLocation = CHROMATICNOTES*4;
	diatonicLocation = DIATONICNOTES*2;
	chromaticBase = DIATONICNOTES*2;
	//Make diatonic scale shape (minor based... not major based)
	for(i=0; i<2;i++)
	{
		scaleShape[0] = i*12 + 0;
		scaleShape[1] = i*12 + 2;
		scaleShape[2] = i*12 + 3;
		scaleShape[3] = i*12 + 5;
		scaleShape[4] = i*12 + 7;
		scaleShape[5] = i*12 + 9;
		scaleShape[6] = i*12 + 10;
	}
	scaleShape[DIATONICNOTES*2]=24;
	for(buf=0; buf<ECHOBUFFERS; buf++)
	{
		for(i=0;i<BEATBUFFER;i++)
		{
			echoVol[buf][i] = 0;
			echoNote[buf][i] = 0;
			echoInterval[buf][i] = 0;
		}
	}
	for(i=0;i<1024;i++)
	{
		keyDownCount[i]=0;
		downKeyPlays[i]=0;
	}
	midiPlatform_init();
	musicTheory_init();
	return self;
}

-(void)tickAt:(uint64_t)now
{
	//play all echoed notes until we are caught up
	int buf=0;
	uint64_t stop = ((now * timebaseInfo.numer / (timebaseInfo.denom*TIMEDIV)))%BEATBUFFER;
	uint64_t idx = ((timePlayed * timebaseInfo.numer / (timebaseInfo.denom*TIMEDIV)))%BEATBUFFER;	
	while(idx != stop)
	{
		for(buf=0; buf<ECHOBUFFERS; buf++)
		{
			int vol = echoVol[buf][idx];
			if(vol>0)
			{
				int note = echoNote[buf][idx];
				[self playEchoedPacketNow:echoScheduled[buf][idx] andCmd:0x90 andNote:note andVol:vol inBuf:buf interval:echoInterval[buf][idx]];
			}
		}
		//Ok... this keeps us from having echo wrap around
		echoVol[buf][idx]=0;
		idx++;		
		idx %= BEATBUFFER;
	}
	timePlayed = now;
}

//Use this to render hints to GUI to show when next cycle begins
-(BOOL)nextCycleAt:(uint64_t)now
{
	if(timeA < timeB)
	{
		if( (now-timeCycled)/(timeB-timeA) > 1)
		{
			timeCycled = now;
			return YES;
		}
	}
	return NO;
}

//Set interval start
-(void)tickStartAt:(uint64_t)now
{
	timeA = now;
}

//Set interval stop
-(void)tickStopAt:(uint64_t)now
{
	timeB = now;
}

-(void)keyDownAt:(uint64_t)now withKeys:(NSString*)chars
{
	int i=0;
	for(i=0; i<[chars length]; i++)
	{
		unichar c = [chars characterAtIndex:i];
		musicTheory_keyDown(c);
	}
	timePlayed = now;
}

-(void)keyUpAt:(uint64_t)now withKeys:(NSString*)chars
{
	int i=0;
	for(i=0; i<[chars length]; i++)
	{
		unichar c = [chars characterAtIndex:i];
		musicTheory_keyUp(c);

	}
	timePlayed = now;
}

-(int*)downKeys
{
	return downKeyPlays;
}

-(void) playEchoedPacketNow:(uint64_t)now andCmd:(int)cmd andNote:(int)note andVol:(int)vol inBuf:(int)buf interval:(uint64_t)interval
{
	//Play the given note
	midiPlatform_sendMidiPacket(cmd,note,vol);
}

-(int)reTranslate:(int)note
{
	//scale number I,II,III,...
	//note in our octave
	int s = note%12;
	int o = note/12;
	for(s=0; s<7; s++)
	{
		if(note%12 == scaleShape[s]%12)
		{
			//note match... shift it diatonic
			int retranslated = s+diatonicRetranslate;
			int ctranslated = chromaticRetranslate;
			while(retranslated < 0)retranslated += 7;
			while(ctranslated < 0)ctranslated += 12;
			retranslated %= 7;
			ctranslated %= 12;
			return o*12 + scaleShape[retranslated]+ctranslated;
		}
	}
	return note;
}

@end
