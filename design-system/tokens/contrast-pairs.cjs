// node tokens/contrast-pairs.cjs tokens/tokens.json -> every component colour pair, light and dark, against WCAG AA (dark refs resolve to dark values)
const T=require(process.argv[2] ?? "./tokens.json");
const get=p=>p.split(".").reduce((o,k)=>o&&o[k],T);
const res=(v,d)=>{let s=typeof v==="string"?v:JSON.stringify(v);return s.replace(/\{([^}]+)\}/g,(m,p)=>{const n=get(p);if(!n)return m;const dv=n.$extensions?.retrospect?.dark;return res(d&&dv!==undefined?dv:n.$value,d)})};
const val=(p,dark)=>{const n=get("color."+p);const v=dark&&n.$extensions?.retrospect?.dark!==undefined?n.$extensions.retrospect.dark:n.$value;return res(v,dark)};
const rgb=h=>{if(h.startsWith("rgba")){const a=h.match(/[\d.]+/g).map(Number);return a}h=h.replace("#","");return [0,2,4].map(i=>parseInt(h.substr(i,2),16)).concat([1])};
const over=(fg,bg)=>{const f=rgb(fg),b=bg.startsWith("rgb(")?bg.match(/[\d.]+/g).map(Number):rgb(bg);const a=f[3];return [0,1,2].map(i=>f[i]*a+b[i]*(1-a))};
const L=c=>{const s=c.map(v=>{v/=255;return v<=0.03928?v/12.92:Math.pow((v+0.055)/1.055,2.4)});return 0.2126*s[0]+0.7152*s[1]+0.0722*s[2]};
const cr=(fg,bg,d)=>{if(bg.startsWith("rgba"))bg="rgb("+over(bg,val("background.canvas",d)).map(Math.round).join(",")+")";const b=bg.startsWith("rgb(")?bg.match(/[\d.]+/g).map(Number):rgb(bg).slice(0,3),f=over(fg,bg);const a=L(f),c=L(b);return (Math.max(a,c)+0.05)/(Math.min(a,c)+0.05)};
const pairs=[
["inference.border","inference.surface",3],["inference.marker","inference.surface",3],
["message.mine","background.canvas",1],["text.primary","message.mine",4.5],
["goal.said","background.raised",3],["goal.did","background.raised",3],
["source.connected","background.canvas",3],["source.problem","background.canvas",3],["source.syncing","background.canvas",3],
["status.dangerText","background.canvas",4.5],["map.nodeLabel","background.canvas",4.5],
["map.node.self","background.canvas",3],["confidence.medium","inference.surface",4.5],
["border.fieldFocus","background.field",3],["accent.text","accent.subtle",4.5],["text.tertiary","background.field",4.5],
["player.progress","surface.track",3],["text.label","surface.wash",4.5],["icon.muted","background.canvas",3],
["text.secondary","background.raised",4.5],["accent.border","background.raised",3],["text.inverse","background.inverse",4.5],
["text.tertiary","surface.washPressed",4.5],["text.label","surface.washPressed",4.5],["text.primary","background.underlay",4.5],["text.label","background.underlay",4.5],["text.primary","background.sunken",4.5],["text.secondary","surface.control",4.5]];
for(const [f,b,min] of pairs)for(const d of [false,true]){const r=cr(val(f,d),val(b,d),d);console.log((r>=min?"  ok ":"FAIL ")+(d?"dark ":"light")+" "+f+" on "+b+" "+r.toFixed(2)+" (need "+min+")  "+val(f,d)+" / "+val(b,d))}
