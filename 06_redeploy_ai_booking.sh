#!/bin/bash
# =====================================================
# BonusVarsel AI Booking — Redeploy med innebygd HTML
# URL: https://bonusvarsel-ai-booking.web.app
# =====================================================
# Kjør: bash ~/Downloads/06_redeploy_ai_booking.sh
# =====================================================

set -e

PROJECT_ID="bonusvarsel-ai-booking"
DEPLOY_DIR="$HOME/bonusvarsel-booking-redeploy"

echo "════════════════════════════════════════════════"
echo "  AI Booking — Redeploy"
echo "  → https://bonusvarsel-ai-booking.web.app"
echo "════════════════════════════════════════════════"

command -v firebase >/dev/null 2>&1 || { echo "❌ Firebase CLI mangler."; exit 1; }

rm -rf "$DEPLOY_DIR"
mkdir -p "$DEPLOY_DIR/public"

cat > "$DEPLOY_DIR/firebase.json" << 'EOF'
{
  "hosting": {
    "public": "public",
    "ignore": ["firebase.json", "**/.*"],
    "headers": [{ "source": "**", "headers": [{ "key": "Cache-Control", "value": "no-cache" }] }]
  }
}
EOF

cat > "$DEPLOY_DIR/.firebaserc" << EOF
{ "projects": { "default": "$PROJECT_ID" } }
EOF

# HTML er innebygd direkte her
cat > "$DEPLOY_DIR/public/index.html" << 'HTMLEOF'
<!DOCTYPE html>
<html lang="nb">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
<title>BonusVarsel AI · Demo</title>
<style>
* { box-sizing: border-box; margin: 0; padding: 0; }
body { min-height: 100vh; display: flex; align-items: center; justify-content: center; background: linear-gradient(145deg, #f5ede6 0%, #fdf6f0 40%, #e8f0eb 100%); padding: 16px; font-family: system-ui, sans-serif; position: relative; overflow: hidden; }
.blob1 { position: fixed; top: -120px; right: -80px; width: 400px; height: 400px; border-radius: 50%; background: radial-gradient(circle, rgba(212,175,140,0.25), transparent 70%); pointer-events: none; }
.blob2 { position: fixed; bottom: -100px; left: -60px; width: 350px; height: 350px; border-radius: 50%; background: radial-gradient(circle, rgba(160,190,170,0.22), transparent 70%); pointer-events: none; }
.phone { width: 100%; max-width: 400px; height: 90vh; max-height: 800px; background: rgba(255,252,249,0.92); backdrop-filter: blur(20px); border-radius: 28px; overflow: hidden; display: flex; flex-direction: column; box-shadow: 0 24px 60px rgba(150,110,80,0.18), 0 0 0 1px rgba(210,185,165,0.4); position: relative; }
.header { background: linear-gradient(135deg, #3d2c1e, #5c4030); padding: 16px 18px; display: flex; align-items: center; gap: 12px; }
.avatar { width: 44px; height: 44px; border-radius: 50%; background: linear-gradient(135deg, #c9956a, #e8c4a0); display: flex; align-items: center; justify-content: center; font-weight: 700; color: #3d2c1e; font-size: 20px; flex-shrink: 0; }
.hname { color: #f5ede6; font-size: 17px; font-weight: 600; }
.honline { color: #a8c9a0; font-size: 11.5px; display: flex; align-items: center; gap: 5px; margin-top: 2px; }
.hdot { width: 7px; height: 7px; border-radius: 50%; background: #7dba7a; box-shadow: 0 0 7px #7dba7a; animation: pulse 2s infinite; }
@keyframes pulse { 0%,100%{opacity:1} 50%{opacity:0.4} }
.hbadge { font-size: 9px; letter-spacing: 1.5px; text-transform: uppercase; color: #e8c4a0; border: 1px solid rgba(232,196,160,0.5); padding: 3px 9px; border-radius: 20px; margin-left: auto; }
.sysbar { display: flex; align-items: center; gap: 6px; padding: 10px 16px; background: rgba(240,230,220,0.6); border-bottom: 1px solid rgba(210,185,165,0.35); flex-wrap: wrap; }
.syslabel { font-size: 10.5px; color: #9a7a65; margin-right: 2px; }
.sysbtn { font-size: 10.5px; padding: 4px 11px; border-radius: 14px; cursor: pointer; font-family: inherit; border: 1px solid rgba(180,150,130,0.4); background: transparent; color: #9a7a65; }
.sysbtn.active { background: linear-gradient(135deg, #5c4030, #3d2c1e); color: #f5ede6; border-color: transparent; }
.chat { flex: 1; overflow-y: auto; padding: 18px 15px; display: flex; flex-direction: column; gap: 11px; }
.chat::-webkit-scrollbar { width: 0; }
.msg { max-width: 83%; padding: 11px 15px; border-radius: 18px; font-size: 14.5px; line-height: 1.6; white-space: pre-wrap; word-break: break-word; animation: fadeUp 0.3s ease; }
@keyframes fadeUp { from{opacity:0;transform:translateY(6px)} to{opacity:1;transform:translateY(0)} }
.msg.ai { background: rgba(255,250,245,0.95); border: 1px solid rgba(210,185,165,0.5); color: #3d2c1e; align-self: flex-start; border-bottom-left-radius: 5px; box-shadow: 0 2px 8px rgba(150,110,80,0.08); }
.msg.user { background: linear-gradient(135deg, #5c4030, #7a5540); color: #f5ede6; align-self: flex-end; border-bottom-right-radius: 5px; }
.typing { display: flex; gap: 5px; align-items: center; padding: 14px 15px; width: 64px; }
.tdot { width: 7px; height: 7px; border-radius: 50%; background: #c9a58a; animation: bounce 1.3s infinite; }
.tdot:nth-child(2){animation-delay:0.18s} .tdot:nth-child(3){animation-delay:0.36s}
@keyframes bounce { 0%,60%,100%{transform:translateY(0);opacity:0.35} 30%{transform:translateY(-5px);opacity:1} }
.chips { display: flex; flex-wrap: wrap; gap: 7px; margin-top: 2px; }
.chip { background: rgba(255,250,245,0.9); border: 1px solid rgba(180,150,130,0.5); color: #7a5540; font-size: 12px; padding: 8px 13px; border-radius: 18px; cursor: pointer; font-family: inherit; }
.bar { display: flex; gap: 9px; padding: 13px 14px; border-top: 1px solid rgba(210,185,165,0.4); background: rgba(250,245,240,0.8); }
.bar input { flex: 1; background: rgba(255,252,249,0.9); border: 1px solid rgba(180,150,130,0.4); border-radius: 22px; padding: 11px 17px; color: #3d2c1e; font-size: 14.5px; outline: none; font-family: inherit; }
.bar input:focus { border-color: #c9956a; }
.send { width: 44px; height: 44px; border-radius: 50%; border: none; background: linear-gradient(135deg, #7a5540, #5c4030); color: #f5ede6; font-size: 17px; cursor: pointer; flex-shrink: 0; }
.send:disabled { opacity: 0.5; }
.foot { text-align: center; font-size: 10px; color: #b09a8a; padding: 5px 0 10px; }
</style>
</head>
<body>
<div class="blob1"></div><div class="blob2"></div>
<div class="phone">
  <div class="header">
    <div class="avatar">S</div>
    <div style="flex:1">
      <div class="hname">Salong Nord</div>
      <div class="honline"><span class="hdot"></span> Svarer vanligvis straks</div>
    </div>
    <div class="hbadge">AI · 24/7</div>
  </div>
  <div class="sysbar">
    <span class="syslabel">Bookingsystem:</span>
    <button class="sysbtn active" onclick="setSystem(this,'fixit')">Fixit</button>
    <button class="sysbtn" onclick="setSystem(this,'timma')">Timma</button>
    <button class="sysbtn" onclick="setSystem(this,'ledigtime')">Ledigtime</button>
    <button class="sysbtn" onclick="setSystem(this,'ingen')">Ingen</button>
  </div>
  <div class="chat" id="chat"></div>
  <div class="bar">
    <input id="inp" type="text" placeholder="Skriv en melding…" onkeydown="if(event.key==='Enter')send()">
    <button class="send" id="sendbtn" onclick="send()">➤</button>
  </div>
  <div class="foot">Demo av BonusVarsel AI · bonusvarsel.no</div>
</div>
<script>
let history=[],currentSystem='fixit',loading=false,chipsShown=false;
const CHIPS=["Jeg vil bestille herreklipp","Hva koster balayage?","Har Mia tid i morgen?","Jeg har litt ettervekst"];
const PRISER={herreklipp:490,skjegg:250,"herreklipp og skjegg":690,dameklipp:690,barneklipp:350,ettervekst:950,balayage:2200,"balayage og ettervekst":3000,foilstriper:1450};
function setSystem(btn,sys){document.querySelectorAll('.sysbtn').forEach(b=>b.classList.remove('active'));btn.classList.add('active');currentSystem=sys;}
function getPersonFromHistory(msgs){for(let i=msgs.length-1;i>=0;i--){const t=(msgs[i].text||'').toLowerCase();if(t.includes('mia'))return'mia';if(t.includes('jonas'))return'jonas';if(t.includes('sara'))return'sara';}return null;}
function finnTid(msgs){for(let i=msgs.length-1;i>=0;i--){if(msgs[i].role!=='user')continue;const m=msgs[i].text.match(/(kl\.?\s*\d{1,2}[.:]\d{2}|kl\.?\s*\d{1,2}|\d{1,2}[.:]\d{2})/i);if(m)return m[1];}for(let i=msgs.length-1;i>=0;i--){const m=msgs[i].text.match(/(kl\.?\s*\d{1,2}[.:]\d{2}|kl\.?\s*\d{1,2})/i);if(m)return m[1];}return null;}
function bekreft(navn,tid,frisor,tlf){const s=currentSystem;const slutt=s==='timma'?'Salongen bekrefter timen din i Timma — du får SMS så snart de har godkjent 😊':s==='ledigtime'?'Salongen bekrefter timen din i Ledigtime — du får SMS så snart de har godkjent 😊':s==='ingen'?'Salongen tar kontakt for å bekrefte — du hører fra dem innen kort tid 😊':'Salongen bekrefter timen din i Fixit — du får SMS så snart de har godkjent 😊';const tlfL=tlf?'\n📱 '+tlf:'';return`Takk, ${navn}! ✨\n\nDin time er booket:\n👤 ${navn}${tlfL}\n📅 ${tid}\n✂️ ${frisor}\n\n${slutt}`;}
function getReply(text){const t=text.toLowerCase();
const harBooket=[...history].reverse().find(m=>m.role==='ai'&&m.text.includes('Din time er booket'));
const villEndre=t.match(/nei|endre|heller|faktisk|glemte|vil ha|bytte|flytte/);
if(harBooket&&villEndre&&t.match(/kl\s*\d|\d{1,2}[.:]\d{2}/)){const alleTider=text.match(/(kl\.?\s*\d{1,2}[.:]?\d{0,2})/gi);const nyTid=alleTider?alleTider[alleTider.length-1]:'ny tid';const navn=(harBooket.text.match(/👤 ([\wæøåÆØÅ]+)/)||[])[1]||'deg';const tlf=(harBooket.text.match(/📱 (\d{8})/)||[])[1]||'';const frisor=(harBooket.text.match(/✂️ ([\wæøåÆØÅ]+)/)||[])[1]||'riktig frisør';return`Klart, ${navn}! ✨ Jeg har endret timen din:\n\n👤 ${navn}${tlf?'\n📱 '+tlf:''}\n📅 ${nyTid} (endret)\n✂️ ${frisor}\n\nSalongen oppdaterer bookingen — du får ny SMS-bekreftelse 😊`;}
if(t.match(/\d{8}/)){const allMsgs=[...history,{role:'user',text}];const person=getPersonFromHistory(allMsgs);const frisor=person?{mia:'Mia',jonas:'Jonas',sara:'Sara'}[person]:'riktig frisør';const tid=finnTid(allMsgs);const stoppord=new Set(['navn','tlf','telefon','det','er','og','jeg','hei','min','mitt','mobil','nummer']);const ord=text.match(/\b([a-zA-ZæøåÆØÅ]{2,})\b/g)||[];const navnK=ord.find(o=>!stoppord.has(o.toLowerCase()));const navn=navnK?navnK.charAt(0).toUpperCase()+navnK.slice(1).toLowerCase():'deg';const tlf=(text.match(/\d{8}/)||[])[0]||'';if(!tid)return'Hvilken tid passer best? 😊 Jeg trenger også:\n\nNavn: ...\nTlf: ...\nTid: ...';return bekreft(navn,tid,frisor,tlf);}
if(t.match(/kl\s*\d|^\d{1,2}[:.]\d{2}$|^\d{1,2}$/)&&history.length>=2){const lastAi=[...history].reverse().find(m=>m.role==='ai');if(lastAi&&(lastAi.text.includes('ledig')||lastAi.text.includes('passer best')||lastAi.text.includes('Vil du bestille')))return'Supert! 😊 For å bekrefte timen trenger jeg:\n\nNavn: ...\nTlf: ...';}
if(t.match(/herre|mann|gutt|skjegg|barber|fade/)){if(t.match(/skjegg/)&&t.match(/herre|klipp/))return'Herreklipp + skjeggklipp hos Jonas koster 690 kr samlet (spart 50 kr). Han har ledig i morgen kl 11:00 og 13:30 — hvilken tid passer best? 💈';if(t.match(/skjegg/)&&!t.match(/herre|klipp/))return'Skjeggklipp hos Jonas koster 250 kr. Han har ledig i morgen kl 11:00 og 13:30 — hvilken tid passer best? 💈';return'Jonas er vår herreklipp- og skjeggspesialist. Herreklipp koster 490 kr. Han har ledig i morgen kl 11:00 og 13:30 — hvilken tid passer best?';}
if(t.match(/dameklipp|klippe håret|trenger klipp/)&&!t.match(/farge|balayage/))return'Sara tar seg av dameklipp og styling. Dameklipp koster 690 kr (inkl. vask og føn). Hun har ledig i morgen kl 09:00 og 14:00 — passer noe av det?';
if(t.match(/ettervekst|etterfarge|røtter|vokse ut/))return'Ettervekstfarge koster fra 950 kr — rask og fin behandling! Mia har ledig i morgen kl 10:00 og 15:00. Passer det?';
if(t.match(/balayage|foil|strip|ombré|highlight/)){if(t.match(/ettervekst|begge/))return'Balayage + ettervekstfarge hos Mia koster fra 3 000 kr samlet. Hun har ledig i morgen kl 10:00 og 15:00. Passer det? ✨';return'Balayage starter fra 2 200 kr — Mia er fargeeksperten vår! Hun har ledig i morgen kl 10:00 og 15:00. Vil du bestille? ✨';}
if(t.match(/farge|farging/))return'Vi tilbyr ettervekstfarge fra 950 kr og balayage fra 2 200 kr. Hva trenger du — bare ettervekst, eller noe mer?';
if(t.match(/pris|kost|kr\b|betale|hva tar|ca pris|totalt|sum|begge/)){const hB=t.match(/balayage/),hE=t.match(/ettervekst/),hH=t.match(/herre/),hS=t.match(/skjegg/);if(hB&&hE)return'Balayage + ettervekstfarge hos Mia koster fra 3\u202f000 kr samlet. Mia har ledig i morgen kl 10:00 og 15:00. Vil du bestille begge? 😊';if(hH&&hS)return'Herreklipp + skjeggklipp hos Jonas koster 690 kr samlet. Han har ledig i morgen kl 11:00 og 13:30. Vil du bestille begge? 💈';return'Prisliste:\n\n✂️ Herreklipp: 490 kr\n✂️ Herreklipp + skjegg: 690 kr\n💇 Dameklipp: 690 kr\n👶 Barneklipp: 350 kr\n🎨 Ettervekstfarge: fra 950 kr\n🌟 Balayage: fra 2 200 kr\n✨ Balayage + ettervekst: fra 3 000 kr\n\nHva ønsker du å bestille? 😊';}
if(t.match(/åpen|stengt|åpningstid|når er dere/))return'Vi er åpne mandag–fredag kl 09–18 og lørdag kl 10–15. Søndager stengt. Vil du bestille time? 😊';
if(t.match(/ledig|bestill|book|time\b|morgen|uke/))return'Hva slags behandling ønsker du? Så finner jeg den beste ledige tiden for deg 😊';
const person=getPersonFromHistory([...history,{role:'user',text}]);
if(person){const info={mia:['Mia','farge og balayage','kl 10:00 og 15:00'],jonas:['Jonas','herreklipp og skjegg','kl 11:00 og 13:30'],sara:['Sara','dameklipp og styling','kl 09:00 og 14:00']}[person];return`${info[0]} spesialiserer seg på ${info[1]}. Ledige tider i morgen: ${info[2]}. Vil du bestille? 📅`;}
if(t.match(/takk|super|perfekt|bra|flott/))return'Veldig hyggelig! Vi gleder oss til å se deg 🌸';
return'Kan du si litt mer om hva du trenger? Så hjelper jeg deg med en gang 😊';}
function addMsg(text,role){const chat=document.getElementById('chat');const div=document.createElement('div');div.className='msg '+role;div.textContent=text;chat.appendChild(div);chat.scrollTop=chat.scrollHeight;}
function showTyping(){const chat=document.getElementById('chat');const div=document.createElement('div');div.className='msg ai typing';div.id='typing';div.innerHTML='<span class="tdot"></span><span class="tdot"></span><span class="tdot"></span>';chat.appendChild(div);chat.scrollTop=chat.scrollHeight;}
function hideTyping(){const t=document.getElementById('typing');if(t)t.remove();}
function showChips(){if(chipsShown)return;chipsShown=true;const chat=document.getElementById('chat');const div=document.createElement('div');div.className='chips';CHIPS.forEach(c=>{const btn=document.createElement('button');btn.className='chip';btn.textContent=c;btn.onclick=()=>{div.remove();sendText(c);};div.appendChild(btn);});chat.appendChild(div);chat.scrollTop=chat.scrollHeight;}
function send(){const inp=document.getElementById('inp');const text=inp.value.trim();if(!text||loading)return;inp.value='';sendText(text);}
function sendText(text){if(loading)return;loading=true;document.getElementById('sendbtn').disabled=true;history.push({role:'user',text});addMsg(text,'user');showTyping();setTimeout(()=>{hideTyping();const reply=getReply(text);history.push({role:'ai',text:reply});addMsg(reply,'ai');loading=false;document.getElementById('sendbtn').disabled=false;document.getElementById('inp').focus();},600+Math.random()*400);}
window.onload=()=>{setTimeout(()=>{const w='Hei og velkommen til Salong Nord! 🌿 Jeg kan svare på spørsmål og bestille time – hva kan jeg hjelpe med?';history.push({role:'ai',text:w});addMsg(w,'ai');showChips();},400);};
</script>
</body>
</html>
HTMLEOF

echo "✅ HTML innebygd"

cd "$DEPLOY_DIR"
firebase use "$PROJECT_ID"
echo "🚀 Deployer booking-demoen..."
firebase deploy --only hosting --project "$PROJECT_ID"

echo ""
echo "════════════════════════════════════════════════"
echo "  ✅ LIVE!"
echo "  🔗 https://bonusvarsel-ai-booking.web.app"
echo "════════════════════════════════════════════════"
