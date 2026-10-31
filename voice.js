/* DIGO v2.0 PRIVATE Voice Beta — no recording, no third-party voice API.
 * WebRTC carries audio; Supabase private Realtime broadcast exchanges WebRTC signaling.
 * A TURN relay is not configured: calls may fail across restrictive NAT/mobile networks.
 */
(() => {
  'use strict';

  const iceServers=[{urls:['stun:stun.l.google.com:19302','stun:stun1.l.google.com:19302']}];

  async function join({supabase,roomId,user,onStatus}){
    if(!window.RTCPeerConnection||!navigator.mediaDevices?.getUserMedia)
      throw Error('Voice chat requires a browser with WebRTC microphone support and HTTPS.');
    if(!supabase||!user?.id||!/^[0-9a-f-]{36}$/.test(roomId))
      throw Error('Sign in and enter a private room to use voice.');

    let localStream;
    try{
      localStream=await navigator.mediaDevices.getUserMedia({
        audio:{echoCancellation:true,noiseSuppression:true,autoGainControl:true},
        video:false
      });
    }catch(e){
      throw Error(e?.name==='NotAllowedError'
        ?'Microphone permission was denied. Allow microphone access for DIGO in your browser.'
        :'Could not start your microphone: '+String(e?.message||'Check the device and permissions.'));
    }

    let active=true,subscribed=false,muted=false,audioBlocked=false;
    let members=[],channel=null;
    const peers=new Map(), pendingCandidates=new Map(), audioNodes=new Map();

    function update(status='on',error=''){
      if(!active)return;
      try{onStatus({status,muted,members,audioBlocked,error});}catch(e){console.warn('DIGO voice UI',e);}
    }
    function emit(to,action,body={}){
      if(!active||!subscribed||!channel)return;
      void channel.send({
        type:'broadcast',event:'voice-signal',
        payload:{from:user.id,to,action,...body}
      }).catch(e=>console.warn('DIGO voice signal send',e));
    }
    function disposePeer(id){
      const pc=peers.get(id);
      if(pc){peers.delete(id);try{pc.close()}catch{}}
      pendingCandidates.delete(id);
      const audio=audioNodes.get(id);
      if(audio){audio.pause();audio.srcObject=null;audio.remove();audioNodes.delete(id);}
    }
    function peerConnection(id){
      if(peers.has(id))return peers.get(id);
      const pc=new RTCPeerConnection({iceServers});
      peers.set(id,pc);
      for(const track of localStream.getAudioTracks())pc.addTrack(track,localStream);
      pc.onicecandidate=e=>{
        if(e.candidate)emit(id,'candidate',{candidate:e.candidate.toJSON()});
      };
      pc.ontrack=e=>{
        if(!active||!e.streams?.[0])return;
        let audio=audioNodes.get(id);
        if(!audio){
          audio=document.createElement('audio');
          audio.autoplay=true;
          audio.playsInline=true;
          audio.setAttribute('aria-label','Voice audio from another DIGO participant');
          audio.style.display='none';
          document.body.appendChild(audio);
          audioNodes.set(id,audio);
        }
        audio.srcObject=e.streams[0];
        void audio.play().then(()=>{if(audioBlocked){audioBlocked=false;update();}})
          .catch(()=>{audioBlocked=true;update();});
      };
      pc.onconnectionstatechange=()=>{
        if(!active)return;
        if(pc.connectionState==='failed'){
          console.warn('DIGO voice peer connection failed',id);
          update('on','Audio connection failed for a participant. Try leaving and rejoining. Some networks require a TURN relay.');
        }
      };
      return pc;
    }
    async function addCandidates(id,pc){
      const queued=pendingCandidates.get(id)||[];
      pendingCandidates.delete(id);
      for(const candidate of queued){
        try{await pc.addIceCandidate(new RTCIceCandidate(candidate));}
        catch(e){console.debug('DIGO voice pending ICE',e);}
      }
    }
    async function startOffer(id){
      if(!active||peers.has(id)||id===user.id||!subscribed)return;
      try{
        const pc=peerConnection(id);
        const offer=await pc.createOffer();
        if(!active||!peers.has(id))return;
        await pc.setLocalDescription(offer);
        emit(id,'offer',{description:pc.localDescription.toJSON()});
      }catch(e){console.warn('DIGO voice offer error',e);disposePeer(id);}
    }
    async function incoming(payload){
      if(!active||!payload||payload.from===user.id||payload.to!==user.id)return;
      const from=String(payload.from||'');
      // Accept signaling only from an account currently advertising voice Presence.
      if(!members.some(p=>p.id===from))return;
      if(payload.action==='bye'){disposePeer(from);return;}
      if(!['offer','answer','candidate'].includes(payload.action))return;
      try{
        const pc=peerConnection(from);
        if(payload.action==='offer'){
          await pc.setRemoteDescription(new RTCSessionDescription(payload.description));
          await addCandidates(from,pc);
          const answer=await pc.createAnswer();
          await pc.setLocalDescription(answer);
          emit(from,'answer',{description:pc.localDescription.toJSON()});
        }else if(payload.action==='answer'){
          if(pc.signalingState!=='have-local-offer')return;
          await pc.setRemoteDescription(new RTCSessionDescription(payload.description));
          await addCandidates(from,pc);
        }else if(payload.candidate){
          if(pc.remoteDescription)await pc.addIceCandidate(new RTCIceCandidate(payload.candidate));
          else{
            const list=pendingCandidates.get(from)||[];
            if(list.length<64)list.push(payload.candidate);
            pendingCandidates.set(from,list);
          }
        }
      }catch(e){console.warn('DIGO voice signaling error',e);}
    }
    function syncPresence(){
      if(!active||!channel||!subscribed)return;
      const state=channel.presenceState();
      // Unique user IDs. The list is live Realtime presence, NOT old room member records.
      const unique=new Map();
      for(const p of Object.values(state).flat()){
        if(p?.id&&!unique.has(p.id))unique.set(p.id,{id:p.id,name:p.name||'Member'});
      }
      members=[...unique.values()];
      const present=new Set(members.map(p=>p.id));
      for(const id of [...peers.keys()])if(!present.has(id))disposePeer(id);
      update('on');
      // Lowest UUID creates the offer; the highest answers. This avoids glare.
      for(const p of members){
        if(p.id!==user.id&&user.id<p.id&&!peers.has(p.id))void startOffer(p.id);
      }
    }

    async function leave(){
      if(!active)return;
      if(subscribed){
        for(const peer of peers.keys())emit(peer,'bye');
      }
      active=false;
      window.removeEventListener('pagehide',leave);
      for(const id of [...peers.keys()])disposePeer(id);
      for(const track of localStream.getTracks())track.stop();
      if(channel){
        try{await channel.untrack();}catch{}
        try{await supabase.removeChannel(channel);}catch{}
      }
      members=[];
    }
    const api={
      leave,
      mute(value){
        muted=typeof value==='boolean'?value:!muted;
        for(const track of localStream.getAudioTracks())track.enabled=!muted;
        update();
        return muted;
      },
      async resumeAudio(){
        audioBlocked=false;
        for(const audio of audioNodes.values()){
          try{await audio.play();}catch{audioBlocked=true;}
        }
        update();
      }
    };
    window.addEventListener('pagehide',leave);
    try{
      await supabase.realtime.setAuth();
      if(!active)throw Error('Voice session cancelled.');
      channel=supabase.channel('voice:'+roomId,{
        config:{private:true,presence:{key:user.id},broadcast:{ack:true}}
      });
      channel.on('broadcast',{event:'voice-signal'},({payload})=>{void incoming(payload);});
      channel.on('presence',{event:'sync'},syncPresence);
      channel.on('presence',{event:'join'},syncPresence);
      channel.on('presence',{event:'leave'},syncPresence);
      update('connecting');
      await new Promise((resolve,reject)=>{
        let settled=false;
        const timer=setTimeout(()=>{
          if(!settled){settled=true;reject(Error('Voice connection timed out. Check Supabase voice policies and your internet connection.'));}
        },15000);
        const finish=(error)=>{
          if(settled)return;settled=true;clearTimeout(timer);
          if(error)reject(error);else resolve();
        };
        channel.subscribe(async(status,error)=>{
          if(!active){finish(Error('Voice session cancelled.'));return;}
          if(status==='SUBSCRIBED'){
            subscribed=true;
            try{
              const result=await channel.track({id:user.id,name:user.display_name,joinedAt:new Date().toISOString()});
              if(result!=='ok')throw Error('Voice Presence could not connect: '+String(result));
              syncPresence();
              finish();
            }catch(e){finish(e);}
          }else if(status==='CHANNEL_ERROR'||status==='TIMED_OUT'||status==='CLOSED'){
            const msg='Voice Realtime connection failed: '+String(error?.message||status)+'. Check the voice SQL migration.';
            finish(Error(msg));
            if(active&&settled&&subscribed)update('error',msg);
          }
        });
      });
      update('on');
      return api;
    }catch(e){
      await leave();
      throw e;
    }
  }

  window.DIGOVoice={join};
})();
