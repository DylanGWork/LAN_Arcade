import{r as e}from"./rolldown-runtime-QTnfLwEv.js";import{i as t,n,t as r}from"./vendor-react-BXfsOOax.js";import{n as i}from"./index-DfWdTlXp.js";var a=e(t(),1),o=n(),s=[{title:`⚡ Energy & Metabolism`,traits:[{label:`Metabolism Rate`,key:`metabolismRate`,min:.5,max:2,step:.1,maxDelta:.5},{label:`Energy Efficiency`,key:`energyEfficiency`,min:.5,max:1.5,step:.1,maxDelta:.5},{label:`Photosynthesis`,key:`photosynthesis`,min:0,max:1,step:.05,maxDelta:.4}]},{title:`💪 Physical Stats`,traits:[{label:`Size`,key:`size`,min:1,max:10,step:.5,maxDelta:2},{label:`Speed`,key:`speed`,min:1,max:10,step:.5,maxDelta:2},{label:`Armor`,key:`armor`,min:0,max:10,step:.5,maxDelta:2},{label:`Regeneration`,key:`regeneration`,min:0,max:5,step:.5,maxDelta:2}]},{title:`👁️ Senses`,traits:[{label:`Vision Range`,key:`visionRange`,min:50,max:500,step:5,maxDelta:100},{label:`Chemotaxis`,key:`chemotaxis`,min:0,max:10,step:.5,maxDelta:2},{label:`Hearing`,key:`hearing`,min:0,max:10,step:.5,maxDelta:2}]},{title:`🧠 Behavioral`,traits:[{label:`Aggression`,key:`aggression`,min:0,max:10,step:.5,maxDelta:2},{label:`Intelligence`,key:`intelligence`,min:0,max:10,step:.5,maxDelta:2},{label:`Fear Response`,key:`fearResponse`,min:0,max:10,step:.5,maxDelta:2}]},{title:`✨ Special Abilities`,traits:[{label:`Toxin Strength`,key:`toxinStrength`,min:0,max:10,step:.5,maxDelta:2},{label:`Speed Burst`,key:`speedBurstPower`,min:0,max:10,step:.5,maxDelta:2},{label:`Camouflage`,key:`camouflage`,min:0,max:10,step:.5,maxDelta:2}]},{title:`🌍 Environmental`,traits:[{label:`Temperature Tolerance`,key:`temperatureTolerance`,min:0,max:10,step:.5,maxDelta:2},{label:`Pressure Resistance`,key:`pressureResistance`,min:0,max:10,step:.5,maxDelta:2},{label:`Toxin Resistance`,key:`toxinResistance`,min:0,max:10,step:.5,maxDelta:2}]}],c=({currentTraits:e,availableDNA:t,generation:n,onApply:c})=>{let[l,u]=(0,a.useState)({}),[d,f]=(0,a.useState)(0),[p,m]=(0,a.useState)(``);a.useEffect(()=>{let e=e=>{e.key===`Escape`&&(e.preventDefault(),c({}))};return document.addEventListener(`keydown`,e),()=>document.removeEventListener(`keydown`,e)},[c]);let h=e=>{let t=String(e??1);if(t.includes(`e-`)){let e=Number(t.split(`e-`)[1]??0);return Number.isFinite(e)?e:0}return(t.includes(`.`)?t.split(`.`)[1]??``:``).length},g=(e,t)=>e.toFixed(h(t)),_=t=>{let n=e[t.key];return{min:Math.max(t.min,n-t.maxDelta),max:Math.min(t.max,n+t.maxDelta)}},v=(e,t)=>{let n=_(t),r=Math.max(n.min,Math.min(n.max,e)),i=Math.round(r/t.step)*t.step,a=Math.max(0,h(t.step));return Number(i.toFixed(a))},y=t=>{let n=0;for(let[r,a]of Object.entries(t))if(a!==void 0){let t=e[r],o=Math.abs(a-t);n+=o*i.DNA_COST_PER_TRAIT_CHANGE}return Number(n.toFixed(2))},b=(n,r)=>{if(!Number.isFinite(r)){m(`Enter a number for the trait value.`);return}let i=e[n.key],a=v(r,n),o={...l};Math.abs(a-i)<n.step/2?delete o[n.key]:o[n.key]=a;let s=y(o);u(o),f(s),m(s>t?`Need ${(s-t).toFixed(1)} more DNA points for these changes.`:``)},x=()=>{if(d>t){m(`Need ${(d-t).toFixed(1)} more DNA points before applying.`);return}c(l)},S=()=>{c({})},C=()=>{u({}),f(0),m(``)},w=t=>{let n=e[t.key],r=l[t.key]??n,a=Math.abs(r-n)>=t.step/2,s=_(t),c=r-n,u=Math.abs(c)*i.DNA_COST_PER_TRAIT_CHANGE;return(0,o.jsxs)(`div`,{className:`trait-row`,children:[(0,o.jsxs)(`label`,{className:`trait-label`,htmlFor:`trait-${t.key}`,children:[t.label,a&&(0,o.jsx)(`span`,{className:`changed-indicator`,children:`*`})]}),(0,o.jsx)(`input`,{id:`trait-${t.key}`,type:`range`,min:s.min,max:s.max,step:t.step,value:r,onChange:e=>b(t,parseFloat(e.target.value)),className:`trait-slider`}),(0,o.jsx)(`button`,{type:`button`,className:`stepper-button`,onClick:()=>b(t,r-t.step),"aria-label":`Decrease ${t.label}`,children:`-`}),(0,o.jsx)(`input`,{type:`number`,min:s.min,max:s.max,step:t.step,value:g(r,t.step),onChange:e=>b(t,parseFloat(e.target.value)),className:`trait-number`,"aria-label":`${t.label} value`}),(0,o.jsx)(`button`,{type:`button`,className:`stepper-button`,onClick:()=>b(t,r+t.step),"aria-label":`Increase ${t.label}`,children:`+`}),(0,o.jsx)(`span`,{className:`trait-value`,children:a?(0,o.jsxs)(o.Fragment,{children:[(0,o.jsxs)(`span`,{className:`trait-diff`,children:[c>0?`+`:``,g(c,t.step)]}),(0,o.jsxs)(`span`,{className:`trait-cost`,children:[`DNA `,u.toFixed(1)]})]}):(0,o.jsx)(`span`,{className:`trait-diff neutral`,children:`Current`})})]},t.key)};return(0,o.jsx)(`div`,{className:`trait-editor-overlay`,role:`dialog`,"aria-modal":`true`,"aria-labelledby":`trait-editor-title`,"aria-describedby":`trait-editor-description`,children:(0,o.jsx)(r,{returnFocus:!0,children:(0,o.jsxs)(`div`,{className:`trait-editor`,children:[(0,o.jsxs)(`div`,{className:`editor-header`,children:[(0,o.jsxs)(`h2`,{id:`trait-editor-title`,children:[`🧬 Trait Editor - Generation `,n]}),(0,o.jsxs)(`div`,{id:`trait-editor-description`,className:d>t?`dna-display over-budget`:`dna-display`,children:[`DNA Points: `,(t-d).toFixed(1),` / `,t.toFixed(1),d>0&&(0,o.jsxs)(`span`,{className:`dna-spent`,children:[` (-`,d.toFixed(1),`)`]})]}),p&&(0,o.jsx)(`div`,{className:`status-message`,children:p})]}),(0,o.jsx)(`div`,{className:`editor-content`,children:s.map(e=>(0,o.jsxs)(`div`,{className:`trait-section`,children:[(0,o.jsx)(`h3`,{children:e.title}),e.traits.map(w)]},e.title))}),(0,o.jsxs)(`div`,{className:`editor-footer`,children:[(0,o.jsxs)(`div`,{className:`button-group`,children:[(0,o.jsx)(`button`,{onClick:C,className:`btn btn-secondary`,children:`Reset Changes`}),(0,o.jsx)(`button`,{onClick:S,className:`btn btn-secondary`,children:`Skip (No Changes)`}),(0,o.jsx)(`button`,{onClick:x,className:`btn btn-primary`,disabled:d>t,children:Object.keys(l).length===0?`Continue (No Changes)`:`Apply Modifications`})]}),(0,o.jsx)(`div`,{className:`info-text`,children:`Use sliders, +/- buttons, or type a value. Vision can shift by up to 100 per generation; most traits shift by up to 2.`})]}),(0,o.jsx)(`style`,{children:`
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
        }

        .trait-editor {
          background: #1a1e2e;
          border-radius: 12px;
          width: 92%;
          max-width: 980px;
          max-height: 90vh;
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
          padding: 20px;
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
          grid-template-columns: 170px minmax(160px, 1fr) 36px 96px 36px 130px;
          gap: 10px;
          align-items: center;
          margin-bottom: 12px;
        }

        .trait-label {
          color: #ddd;
          font-size: 14px;
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
          width: 36px;
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
          width: 96px;
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

          .trait-label,
          .trait-slider,
          .trait-value {
            grid-column: 1 / -1;
          }

          .trait-value {
            align-items: flex-start;
          }

          .button-group {
            flex-wrap: wrap;
          }

          .btn {
            flex: 1 1 150px;
          }
        }
      `})]})})})};export{c as TraitEditor};