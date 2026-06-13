import{r as e}from"./rolldown-runtime-QTnfLwEv.js";import{i as t,n,t as r}from"./vendor-react-BXfsOOax.js";import{n as i}from"./index-D2ZKFJqF.js";var a=e(t(),1),o=n(),s=[{title:`⚡ Energy & Metabolism`,traits:[{label:`Metabolism Rate`,key:`metabolismRate`,min:.5,max:2,step:.1,maxDelta:.5},{label:`Energy Efficiency`,key:`energyEfficiency`,min:.5,max:1.5,step:.1,maxDelta:.5},{label:`Photosynthesis`,key:`photosynthesis`,min:0,max:1,step:.05,maxDelta:.4}]},{title:`💪 Physical Stats`,traits:[{label:`Size`,key:`size`,min:1,max:10,step:.5,maxDelta:2},{label:`Speed`,key:`speed`,min:1,max:10,step:.5,maxDelta:2},{label:`Armor`,key:`armor`,min:0,max:10,step:.5,maxDelta:2},{label:`Regeneration`,key:`regeneration`,min:0,max:5,step:.5,maxDelta:2}]},{title:`👁️ Senses`,traits:[{label:`Vision Range`,key:`visionRange`,min:50,max:500,step:5,maxDelta:100},{label:`Chemotaxis`,key:`chemotaxis`,min:0,max:10,step:.5,maxDelta:2},{label:`Hearing`,key:`hearing`,min:0,max:10,step:.5,maxDelta:2}]},{title:`🧠 Behavioral`,traits:[{label:`Aggression`,key:`aggression`,min:0,max:10,step:.5,maxDelta:2},{label:`Intelligence`,key:`intelligence`,min:0,max:10,step:.5,maxDelta:2},{label:`Fear Response`,key:`fearResponse`,min:0,max:10,step:.5,maxDelta:2}]},{title:`✨ Special Abilities`,traits:[{label:`Toxin Strength`,key:`toxinStrength`,min:0,max:10,step:.5,maxDelta:2},{label:`Speed Burst`,key:`speedBurstPower`,min:0,max:10,step:.5,maxDelta:2},{label:`Camouflage`,key:`camouflage`,min:0,max:10,step:.5,maxDelta:2}]},{title:`🌍 Environmental`,traits:[{label:`Temperature Tolerance`,key:`temperatureTolerance`,min:0,max:10,step:.5,maxDelta:2},{label:`Pressure Resistance`,key:`pressureResistance`,min:0,max:10,step:.5,maxDelta:2},{label:`Toxin Resistance`,key:`toxinResistance`,min:0,max:10,step:.5,maxDelta:2}]}],c={metabolismRate:{summary:`How quickly cells burn energy and run their body.`,higher:`More active, but ATP falls faster.`,lower:`Conserves ATP, but cells feel less lively.`},energyEfficiency:{summary:`How much work cells get from each ATP point.`,higher:`Better survival because movement and metabolism cost less.`,lower:`Wastes ATP faster.`},photosynthesis:{summary:`Passive ATP gained from bright shallow areas.`,higher:`Offsets ATP drain if the species can stay alive long enough.`,lower:`Pushes the species to forage more.`},size:{summary:`Body size, visibility, and collision presence.`,higher:`Tougher and more imposing, but hungrier and slower to steer.`,lower:`Cheaper to keep alive, but more fragile.`},speed:{summary:`How quickly cells can cross the map.`,higher:`Reaches food and escapes threats sooner, but burns extra ATP.`,lower:`Saves energy but can miss resources.`},armor:{summary:`Reduces combat and environmental damage.`,higher:`Survives hits and harsh biomes longer, but movement gets heavier.`,lower:`Leaves cells exposed but nimble.`},regeneration:{summary:`Health recovered every second while alive.`,higher:`Heals chip damage from fights and hazards.`,lower:`Damage sticks around longer.`},visionRange:{summary:`How far cells can notice food and threats.`,higher:`Finds distant resources, but costs ATP and can trigger distant fear.`,lower:`Less sensory cost, but easier to miss food.`},chemotaxis:{summary:`Chemical sense for tracking nutrients.`,higher:`Better food-seeking behavior.`,lower:`More random wandering.`},hearing:{summary:`Sensitivity to nearby movement and danger.`,higher:`Earlier warning around threats.`,lower:`Less skittish, but easier to surprise.`},aggression:{summary:`How willing cells are to fight.`,higher:`More predator-like behavior and damage, but attacks cost more ATP.`,lower:`More peaceful foraging.`},intelligence:{summary:`Decision quality for survival behavior.`,higher:`Better prioritising food, safety, and reproduction, with a brain-energy cost.`,lower:`Simpler wandering with lower upkeep.`},fearResponse:{summary:`How readily cells flee when danger is nearby.`,higher:`Safer around predators, but may abandon food.`,lower:`Braver around resources, but takes more risks.`},toxinStrength:{summary:`Extra damage when fighting.`,higher:`Better offensive pressure, but toxin upkeep and attacks cost more ATP.`,lower:`Less combat payoff and lower upkeep.`},speedBurstPower:{summary:`Emergency burst movement potential.`,higher:`Better escapes and chases.`,lower:`Steadier but less explosive movement.`},camouflage:{summary:`How hard cells are to notice.`,higher:`Avoids some predator attention.`,lower:`More visible in the ecosystem.`},temperatureTolerance:{summary:`Protection from hot and cold biomes.`,higher:`Less health loss in volcanic or frozen areas.`,lower:`Needs safer temperatures.`},pressureResistance:{summary:`Protection in deep water.`,higher:`Less damage in abyss/deep pressure zones.`,lower:`Best kept in shallow regions.`},toxinResistance:{summary:`Protection from radiation and toxic regions.`,higher:`Less environmental poison/radiation damage.`,lower:`Avoid polluted or crystal-heavy areas.`}},l=e=>`${e.summary}
Higher: ${e.higher}
Lower: ${e.lower}`,u=({currentTraits:e,availableDNA:t,generation:n,onApply:u})=>{let[d,f]=(0,a.useState)({}),[p,m]=(0,a.useState)(0),[h,g]=(0,a.useState)(``);a.useEffect(()=>{let e=e=>{e.key===`Escape`&&(e.preventDefault(),u({}))};return document.addEventListener(`keydown`,e),()=>document.removeEventListener(`keydown`,e)},[u]);let _=e=>{let t=String(e??1);if(t.includes(`e-`)){let e=Number(t.split(`e-`)[1]??0);return Number.isFinite(e)?e:0}return(t.includes(`.`)?t.split(`.`)[1]??``:``).length},v=(e,t)=>e.toFixed(_(t)),y=t=>{let n=e[t.key];return{min:Math.max(t.min,n-t.maxDelta),max:Math.min(t.max,n+t.maxDelta)}},b=(e,t)=>{let n=y(t),r=Math.max(n.min,Math.min(n.max,e)),i=Math.round(r/t.step)*t.step,a=Math.max(0,_(t.step));return Number(i.toFixed(a))},x=t=>{let n=0;for(let[r,a]of Object.entries(t))if(a!==void 0){let t=e[r],o=Math.abs(a-t);n+=o*i.DNA_COST_PER_TRAIT_CHANGE}return Number(n.toFixed(2))},S=(n,r)=>{if(!Number.isFinite(r)){g(`Enter a number for the trait value.`);return}let i=e[n.key],a=b(r,n),o={...d};Math.abs(a-i)<n.step/2?delete o[n.key]:o[n.key]=a;let s=x(o);f(o),m(s),g(s>t?`Need ${(s-t).toFixed(1)} more DNA points for these changes.`:``)},C=()=>{if(p>t){g(`Need ${(p-t).toFixed(1)} more DNA points before applying.`);return}u(d)},w=()=>{u({})},T=()=>{f({}),m(0),g(``)},E=t=>{let n=e[t.key],r=d[t.key]??n,a=Math.abs(r-n)>=t.step/2,s=y(t),u=r-n,f=Math.abs(u)*i.DNA_COST_PER_TRAIT_CHANGE,p=c[t.key];return(0,o.jsxs)(`div`,{className:`trait-row`,children:[(0,o.jsxs)(`label`,{className:`trait-label`,htmlFor:`trait-${t.key}`,children:[(0,o.jsx)(`span`,{className:`trait-label-text`,children:t.label}),p&&(0,o.jsx)(`span`,{className:`trait-help`,tabIndex:0,title:l(p),"aria-label":`${t.label}: ${p.summary}`,children:`?`}),a&&(0,o.jsx)(`span`,{className:`changed-indicator`,children:`*`})]}),(0,o.jsx)(`input`,{id:`trait-${t.key}`,type:`range`,min:s.min,max:s.max,step:t.step,value:r,onChange:e=>S(t,parseFloat(e.target.value)),className:`trait-slider`}),(0,o.jsx)(`button`,{type:`button`,className:`stepper-button`,onClick:()=>S(t,r-t.step),"aria-label":`Decrease ${t.label}`,children:`-`}),(0,o.jsx)(`input`,{type:`number`,min:s.min,max:s.max,step:t.step,value:v(r,t.step),onChange:e=>S(t,parseFloat(e.target.value)),className:`trait-number`,"aria-label":`${t.label} value`}),(0,o.jsx)(`button`,{type:`button`,className:`stepper-button`,onClick:()=>S(t,r+t.step),"aria-label":`Increase ${t.label}`,children:`+`}),(0,o.jsx)(`span`,{className:`trait-value`,children:a?(0,o.jsxs)(o.Fragment,{children:[(0,o.jsxs)(`span`,{className:`trait-diff`,children:[u>0?`+`:``,v(u,t.step)]}),(0,o.jsxs)(`span`,{className:`trait-cost`,children:[`DNA `,f.toFixed(1)]})]}):(0,o.jsx)(`span`,{className:`trait-diff neutral`,children:`Current`})})]},t.key)};return(0,o.jsx)(`div`,{className:`trait-editor-overlay`,role:`dialog`,"aria-modal":`true`,"aria-labelledby":`trait-editor-title`,"aria-describedby":`trait-editor-description`,children:(0,o.jsx)(r,{returnFocus:!0,children:(0,o.jsxs)(`div`,{className:`trait-editor`,children:[(0,o.jsxs)(`div`,{className:`editor-header`,children:[(0,o.jsxs)(`h2`,{id:`trait-editor-title`,children:[`🧬 Trait Editor - Generation `,n]}),(0,o.jsxs)(`div`,{id:`trait-editor-description`,className:p>t?`dna-display over-budget`:`dna-display`,children:[`DNA Points: `,(t-p).toFixed(1),` / `,t.toFixed(1),p>0&&(0,o.jsxs)(`span`,{className:`dna-spent`,children:[` (-`,p.toFixed(1),`)`]})]}),h&&(0,o.jsx)(`div`,{className:`status-message`,children:h})]}),(0,o.jsx)(`div`,{className:`editor-content`,onWheel:e=>e.stopPropagation(),onTouchMove:e=>e.stopPropagation(),children:s.map(e=>(0,o.jsxs)(`div`,{className:`trait-section`,children:[(0,o.jsx)(`h3`,{children:e.title}),e.traits.map(E)]},e.title))}),(0,o.jsxs)(`div`,{className:`editor-footer`,children:[(0,o.jsxs)(`div`,{className:`button-group`,children:[(0,o.jsx)(`button`,{onClick:T,className:`btn btn-secondary`,children:`Reset Changes`}),(0,o.jsx)(`button`,{onClick:w,className:`btn btn-secondary`,children:`Skip (No Changes)`}),(0,o.jsx)(`button`,{onClick:C,className:`btn btn-primary`,disabled:p>t,children:Object.keys(d).length===0?`Continue (No Changes)`:`Apply Modifications`})]}),(0,o.jsx)(`div`,{className:`info-text`,children:`Use sliders, +/- buttons, or type a value. Applied changes affect living cells immediately and spend DNA. Bigger, faster, smarter, sensory, armored, and toxic builds now have upkeep costs.`})]}),(0,o.jsx)(`style`,{children:`
        .trait-editor-overlay {
          position: fixed;
          top: 0;
          left: 0;
          width: 100vw;
          height: 100vh;
          background: rgba(0, 0, 0, 0.9);
          display: flex;
          justify-content: center;
          align-items: center;
          z-index: 1000;
          overscroll-behavior: contain;
        }

        .trait-editor {
          background: #1a1e2e;
          border-radius: 8px;
          width: min(1080px, 96vw);
          max-height: min(92vh, 860px);
          overflow: hidden;
          display: flex;
          flex-direction: column;
          box-shadow: 0 10px 40px rgba(0, 0, 0, 0.5);
        }

        .editor-header {
          padding: 20px;
          background: linear-gradient(135deg, #2d3548 0%, #1a1e2e 100%);
          border-bottom: 2px solid #4caf50;
        }

        .editor-header h2 {
          margin: 0 0 10px 0;
          color: #4caf50;
          font-size: 24px;
        }

        .dna-display {
          font-size: 18px;
          color: #fff;
          font-family: 'Courier New', monospace;
        }

        .dna-display.over-budget {
          color: #ff8a80;
        }

        .dna-spent {
          color: #ff9800;
        }

        .status-message {
          margin-top: 8px;
          color: #ffcc80;
          font-size: 13px;
        }

        .editor-content {
          flex: 1;
          overflow-y: auto;
          overflow-x: hidden;
          padding: 20px;
          min-height: 0;
          scrollbar-gutter: stable;
        }

        .trait-section {
          margin-bottom: 30px;
        }

        .trait-section h3 {
          color: #4caf50;
          margin-bottom: 15px;
          font-size: 18px;
        }

        .trait-row {
          display: grid;
          grid-template-columns: minmax(126px, 150px) minmax(96px, 1fr) 34px 86px 34px minmax(82px, 102px);
          gap: 8px;
          align-items: center;
          margin-bottom: 12px;
        }

        .trait-label {
          color: #ddd;
          font-size: 14px;
          display: flex;
          align-items: center;
          gap: 6px;
          min-width: 0;
        }

        .trait-label-text {
          overflow: hidden;
          text-overflow: ellipsis;
          white-space: nowrap;
        }

        .trait-help {
          display: inline-flex;
          align-items: center;
          justify-content: center;
          width: 18px;
          height: 18px;
          flex: 0 0 auto;
          border: 1px solid #4caf50;
          border-radius: 50%;
          color: #b5ffbd;
          font-size: 12px;
          font-weight: bold;
          cursor: help;
        }

        .changed-indicator {
          color: #ff9800;
          margin-left: 5px;
        }

        .trait-slider {
          width: 100%;
          min-width: 0;
        }

        .stepper-button {
          width: 34px;
          height: 34px;
          border: 1px solid #4caf50;
          border-radius: 6px;
          background: #283142;
          color: #fff;
          cursor: pointer;
          font-size: 18px;
          font-weight: bold;
        }

        .stepper-button:hover {
          background: #354158;
        }

        .trait-number {
          width: 86px;
          height: 34px;
          border: 1px solid #4caf50;
          border-radius: 6px;
          background: #0f1219;
          color: #fff;
          padding: 0 8px;
          font-family: 'Courier New', monospace;
          font-size: 14px;
        }

        .trait-value {
          display: flex;
          flex-direction: column;
          align-items: flex-end;
          gap: 2px;
          color: #fff;
          font-family: 'Courier New', monospace;
          font-size: 13px;
        }

        .trait-diff {
          color: #4caf50;
        }

        .trait-diff.neutral {
          color: #888;
        }

        .trait-cost {
          color: #ffcc80;
          font-size: 11px;
        }

        .editor-footer {
          padding: 20px;
          background: #0f1219;
          border-top: 1px solid #333;
        }

        .button-group {
          display: flex;
          gap: 10px;
          margin-bottom: 10px;
        }

        .btn {
          padding: 12px 24px;
          border: none;
          border-radius: 6px;
          font-size: 14px;
          cursor: pointer;
          transition: all 0.2s;
          font-family: inherit;
        }

        .btn-primary {
          background: #4caf50;
          color: white;
        }

        .btn-primary:hover:not(:disabled) {
          background: #45a049;
        }

        .btn-primary:disabled {
          background: #555;
          cursor: not-allowed;
          opacity: 0.5;
        }

        .btn-secondary {
          background: #555;
          color: white;
        }

        .btn-secondary:hover {
          background: #666;
        }

        .info-text {
          color: #aaa;
          font-size: 12px;
          text-align: center;
        }

        @media (max-width: 1080px) {
          .trait-row {
            grid-template-columns: minmax(118px, 1fr) 34px 82px 34px;
            gap: 8px;
          }

          .trait-label,
          .trait-slider,
          .trait-value {
            grid-column: 1 / -1;
          }

          .trait-label-text {
            white-space: normal;
          }

          .trait-value {
            align-items: flex-start;
          }
        }

        @media (max-width: 760px) {
          .trait-editor {
            width: 96%;
          }

          .editor-header,
          .editor-footer,
          .editor-content {
            padding: 14px;
          }

          .trait-row {
            grid-template-columns: 1fr 34px 88px 34px;
            gap: 8px;
          }


          .button-group {
            flex-wrap: wrap;
          }

          .btn {
            flex: 1 1 150px;
          }
        }
      `})]})})})};export{u as TraitEditor};