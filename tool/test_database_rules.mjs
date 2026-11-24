import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {spawn} from 'node:child_process';
import {setTimeout as delay} from 'node:timers/promises';

const host = process.env.FIREBASE_DATABASE_EMULATOR_HOST || '127.0.0.1:19023';
assert.match(host, /^(127\.0\.0\.1|localhost):\d+$/, 'Only a local emulator is allowed');
const ns = 'demo-soilsense-p0';
const base = 'http://' + host;
let emulator, logs = '', passed = 0;
if (process.env.FIREBASE_DATABASE_EMULATOR_JAR) {
  emulator = spawn(process.env.JAVA_EXE || 'java', [
    '-Duser.language=en', '-jar', process.env.FIREBASE_DATABASE_EMULATOR_JAR,
    '--host', '127.0.0.1', '--port', host.split(':')[1],
  ], {windowsHide:true, stdio:['ignore','pipe','pipe']});
  for (const stream of [emulator.stdout, emulator.stderr]) stream.on('data', d => logs=(logs+d).slice(-12000));
}
const encode = v=>Buffer.from(JSON.stringify(v)).toString('base64url');
function jwt(who) {
  const iat=Math.floor(Date.now()/1000);
  const uid=typeof who==='string'?who:who.uid;
  return encode({alg:'none',typ:'JWT'})+'.'+encode({
    iss:'https://securetoken.google.com/'+ns,aud:ns,sub:uid,user_id:uid,
    iat,exp:iat+3600,auth_time:iat,firebase:{sign_in_provider:'custom',identities:{}},
    ...(typeof who==='object'?who.claims:{}),
  })+'.';
}
async function req(path, method='GET', body, who='admin', extra={}) {
  const query='?ns='+ns+(who==='admin'?'':'&auth='+encodeURIComponent(jwt(who)));
  const response=await fetch(base+'/'+path+'.json'+query,{
    method,headers:{...(who==='admin'?{Authorization:'Bearer owner'}:{}),
      'Content-Type':'application/json',...extra},
    ...(body===undefined?{}:{body:JSON.stringify(body)}),signal:AbortSignal.timeout(8000),
  });
  return {status:response.status,body:await response.text(),etag:response.headers.get('etag')};
}
async function check(name,allowed,path,method,body,who) {
  const r=await req(path,method,body,who);
  assert.equal(r.status,allowed?200:401,name+' '+r.status+' '+r.body);
  passed++; console.log('PASS '+name);
  return r;
}
const user='user-a',other='user-b';
const device={uid:'device-a',claims:{device:true,sensorId:'s1'}};
const wrongDevice={uid:'device-b',claims:{device:true,sensorId:'s2'}};
const code='test-only-128-bit-pairing-proof';
const day=()=>Date.now()-Date.now()%86400000;
const packet=()=>({protocolVersion:2,moisture:10,temperature:24,light:60,rawAdc:3000,lastUpdate:Date.now()});
const status=(id,state='completed')=>({protocolVersion:2,commandId:id,actualState:state==='running',state,updatedAt:Date.now()});
function command(id,automatic=false,count=0,last=0) {
  const now=Date.now();
  return {protocolVersion:2,commandId:id,requestedState:true,automatic,
    maxDurationSeconds:15,issuedAt:now,expiresAt:now+20000,
    dayStart:now-now%86400000,autoCount:count,lastAutoAt:automatic?now:last};
}
async function seedPrevious(count,oldDay=day(),last=Date.now()-7200000) {
  const previous={...command('previous-command-id'),autoCount:count,lastAutoAt:last,dayStart:oldDay,
    issuedAt:Date.now()-7200000,expiresAt:Date.now()-7180000};
  await req('pumpCommands/s1','PUT',previous);
  await req('pumpStatus/s1','PUT',status(previous.commandId));
  return previous;
}
try {
  for(let i=0;;i++) {
    if(i>80)throw Error('Emulator unavailable '+logs);
    try {if((await req('')).status===200)break;}catch{}
    await delay(200);
  }
  const rules=JSON.parse(await readFile(new URL('../database.rules.json',import.meta.url),'utf8'));
  const installed=await req('.settings/rules','PUT',rules);
  assert.equal(installed.status,200,'Rule compilation: '+installed.body);
  await req('','PUT',{
    users:{'user-b':{privateValue:1}},
    pairingCodes:{
      s1:{code,expiresAt:Date.now()+600000},
      race:{code,expiresAt:Date.now()+600000},
      expired:{code,expiresAt:Date.now()-1},
    },
  });
  await check('other user data is private',false,'users/user-b','GET',undefined,user);
  await check('pairing secrets are unreadable',false,'pairingCodes/s1','GET',undefined,user);
  await check('client cannot manufacture pairing codes',false,'pairingCodes/madeup','PUT',{code,expiresAt:Date.now()+60000},user);
  await check('wrong pairing code rejected',false,'sensorOwners/s1','PUT',{uid:user,claimCode:'wrong-proof-long-enough'},user);
  await check('cannot claim for another user',false,'sensorOwners/s1','PUT',{uid:other,claimCode:code},user);
  await check('expired code rejected',false,'sensorOwners/expired','PUT',{uid:user,claimCode:code},user);
  await check('valid claim accepted',true,'sensorOwners/s1','PUT',{uid:user,claimCode:code},user);
  await check('claim cannot be reused',false,'sensorOwners/s1','PUT',{uid:other,claimCode:code},other);
  await check('owner cannot delete claim',false,'sensorOwners/s1','DELETE',undefined,user);
  const races=await Promise.all([user,other].map(uid=>req('sensorOwners/race','PUT',{uid,claimCode:code},uid)));
  assert.deepEqual(races.map(r=>r.status).sort(),[200,401]);passed++;console.log('PASS simultaneous ownership has one winner');
  await check('owner reads telemetry',true,'sensors/s1','GET',undefined,user);
  await check('other user cannot read telemetry',false,'sensors/s1','GET',undefined,other);
  await check('owner cannot forge telemetry',false,'sensors/s1/current','PUT',packet(),user);
  await check('wrong device cannot write telemetry',false,'sensors/s1/current','PUT',packet(),wrongDevice);
  await check('device writes telemetry',true,'sensors/s1/current','PUT',packet(),device);
  await check('missing moisture rejected',false,'sensors/s1/current','PUT',{...packet(),moisture:null},device);
  await check('uptime timestamp rejected',false,'sensors/s1/current','PUT',{...packet(),lastUpdate:60000},device);
  await check('bad ADC rejected',false,'sensors/s1/current','PUT',{...packet(),rawAdc:9999},device);
  await check('owner config accepted',true,'sensorConfigs/s1','PUT',{autoWatering:true,minMoisture:30,maxMoisture:75,maxPumpSeconds:15},user);
  await check('device cannot change limits',false,'sensorConfigs/s1/maxPumpSeconds','PUT',30,device);
  await check('unbounded duration rejected',false,'sensorConfigs/s1/maxPumpSeconds','PUT',99999,user);
  await check('bad threshold order rejected',false,'sensorConfigs/s1/minMoisture','PUT',90,user);
  await check('owner cannot forge pump status',false,'pumpStatus/s1','PUT',status(''),user);
  await check('device publishes initial idle',true,'pumpStatus/s1','PUT',status('','idle'),device);
  await check('manual command accepted',true,'pumpCommands/s1','PUT',command('manual-command-0001'),user);
  await check('second start while pending rejected',false,'pumpCommands/s1','PUT',command('manual-command-0002'),user);
  await check('cannot mix status into command',false,'pumpCommands/s1','PATCH',{actualState:true},user);
  await check('cannot delete command counters',false,'pumpCommands/s1','DELETE',undefined,user);
  await check('wrong acknowledgement rejected',false,'pumpStatus/s1','PUT',status('not-current-id','running'),device);
  await check('matching acknowledgement accepted',true,'pumpStatus/s1','PUT',status('manual-command-0001','running'),device);
  await check('running device blocks start',false,'pumpCommands/s1','PUT',command('manual-command-0002'),user);
  await check('device completion accepted',true,'pumpStatus/s1','PUT',status('manual-command-0001'),device);
  await check('device cannot restart completed command',false,'pumpStatus/s1','PUT',status('manual-command-0001','running'),device);
  await check('idle cannot erase completion to allow a replay',false,'pumpStatus/s1','PUT',status('manual-command-0001','idle'),device);
  await check('completed heartbeat accepted',true,'pumpStatus/s1','PUT',status('manual-command-0001'),device);
  await check('device cannot issue command',false,'pumpCommands/s1','PUT',command('device-command-0001'),device);
  await check('excess duration rejected',false,'pumpCommands/s1','PUT',{...command('too-long-command'),maxDurationSeconds:31},user);
  await check('expired queued command rejected',false,'pumpCommands/s1','PUT',{...command('old-queued-command'),issuedAt:Date.now()-60000,expiresAt:Date.now()-40000},user);
  for(let count=1;count<=3;count++) {
    await seedPrevious(count-1);
    await check('automatic watering '+count+' accepted',true,'pumpCommands/s1','PUT',command('automatic-command-000'+count,true,count),user);
  }
  let prev=await seedPrevious(3);
  await check('fourth automatic watering rejected',false,'pumpCommands/s1','PUT',command('automatic-command-0004',true,4),user);
  await check('manual request cannot reset limit',false,'pumpCommands/s1','PUT',command('reset-counter-command',false,0,prev.lastAutoAt),user);
  prev=await seedPrevious(1,day(),Date.now()-60000);
  await check('cooldown survives another client',false,'pumpCommands/s1','PUT',command('too-soon-command',true,2),user);
  await seedPrevious(3,day()-86400000);
  await check('UTC next day starts new bucket',true,'pumpCommands/s1','PUT',command('new-day-command',true,1),user);
  await seedPrevious(0);
  const etag=await req('pumpCommands/s1','GET',undefined,user,{'X-Firebase-ETag':'true'});
  const simultaneous=await Promise.all(['phone-a-command','phone-b-command'].map(id=>
    req('pumpCommands/s1','PUT',command(id,true,1),user,{'if-match':etag.etag})));
  assert.deepEqual(simultaneous.map(r=>r.status).sort(),[200,412]);passed++;console.log('PASS concurrent command compare-and-set has one winner');
  console.log(JSON.stringify({passed,namespace:ns,liveFirebaseUsed:false}));
} finally {
  if(emulator) {
    emulator.kill();
    await new Promise(resolve=>{
      if(emulator.exitCode!==null)resolve();
      else {emulator.once('exit',resolve);setTimeout(resolve,3000).unref();}
    });
  }
}
