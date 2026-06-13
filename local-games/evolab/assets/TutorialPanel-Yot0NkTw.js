import{r as e}from"./rolldown-runtime-QTnfLwEv.js";import{i as t,n,t as r}from"./vendor-react-BXfsOOax.js";var i=e(t(),1),a=n(),o=[{title:`Welcome to EvoLab!`,content:`EvoLab is an evolution simulator where you guide a cell through survival and reproduction.

Your goal is to survive, collect resources, and evolve through generations by modifying traits.`},{title:`Basic Controls`,content:`Auto Mode steers your species automatically. Turn Auto Mode off to use WASD or Arrow Keys as a species-wide nudge.

Mouse: use the zoom controls or wheel to inspect the lake.

The cyan cells are your species; red/yellow/green cells are competing species.`},{title:`Energy & Survival`,content:`ATP Energy: Your cell consumes ATP constantly. When it reaches zero, you die.

Resources: Collect green glucose particles to restore ATP.

Compounds: Collect amino acids (blue) and phosphates (yellow) for reproduction.`},{title:`Biomes & Environment`,content:`The lake has 7 different biomes, each with unique properties:
- Shallow Warm: Rich in glucose
- Deep Cold: Slower movement
- Toxic: Damages health over time
- Nutrient Rich: Extra resources

Day/Night Cycle: Light levels affect visibility and resource availability.`},{title:`Traits & Evolution`,content:`Your cell has 55+ genetic traits including:
- Size, Speed, Strength
- Intelligence, Senses
- Photosynthesis, Toxin Production
- Armor, Camouflage

Each trait affects your survival and capabilities.`},{title:`Reproduction`,content:`Requirements:
- 100 Glucose
- 50 Amino Acids
- 30 Phosphates
- 50 ATP

When ready, you'll see the Trait Editor where you can spend DNA points to modify your offspring's traits.

Mutations: Random changes occur naturally, driving evolution.`},{title:`AI Species`,content:`You're not alone! Three AI species compete for survival:

Herbivores (Green): Peaceful, gather resources, flee from danger.

Carnivores (Red): Aggressive predators that hunt other cells.

Omnivores (Yellow): Balanced species that gather and hunt opportunistically.`},{title:`Combat System`,content:`Combat occurs when cells collide:
- Damage = (Size × 0.5) + (Toxin × 0.5)
- Armor reduces incoming damage by 10% per point
- Speed helps you escape predators
- Size makes you harder to kill but slower`},{title:`Data Visualization`,content:`Track your progress with charts:
- Population Graph: See species populations over time
- Evolution Tree: View your lineage
- Trait Radar: Analyze your trait profile

Export your best creatures to save them!`},{title:`Time Controls`,content:`Control simulation speed:
- 1x: Normal speed
- 10x: Fast forward
- 100x: Very fast
- 1000x: Ultra fast

Pause: Stop time completely
Step: Advance one frame at a time for detailed analysis`},{title:`Tips for Success`,content:`1. Balance your traits - don't max out everything
2. Adapt to your environment's biome
3. Avoid carnivores early on
4. Photosynthesis can provide passive energy
5. Save successful creatures for later
6. Experiment with different strategies!

Good luck, and may evolution be with you!`}],s=({onClose:e})=>{let[t,n]=(0,i.useState)(0);i.useEffect(()=>{let t=t=>{t.key===`Escape`&&(t.preventDefault(),e())};return document.addEventListener(`keydown`,t),()=>document.removeEventListener(`keydown`,t)},[e]);let s=()=>{t<o.length-1?n(t+1):e()},c=()=>{t>0&&n(t-1)},l=o[t];return l?(0,a.jsx)(`div`,{role:`dialog`,"aria-modal":`true`,"aria-labelledby":`tutorial-title`,style:{position:`fixed`,top:0,left:0,right:0,bottom:0,background:`rgba(0, 0, 0, 0.9)`,display:`flex`,justifyContent:`center`,alignItems:`center`,zIndex:1e3},onClick:e,children:(0,a.jsx)(r,{returnFocus:!0,children:(0,a.jsxs)(`div`,{style:{background:`#1a1a1a`,border:`2px solid #60a5fa`,borderRadius:`12px`,padding:`30px`,maxWidth:`600px`,width:`90%`},onClick:e=>e.stopPropagation(),children:[(0,a.jsxs)(`div`,{style:{marginBottom:`20px`},children:[(0,a.jsxs)(`div`,{style:{display:`flex`,justifyContent:`space-between`,marginBottom:`5px`},children:[(0,a.jsxs)(`span`,{style:{color:`#888`,fontSize:`12px`},children:[`Step `,t+1,` of `,o.length]}),(0,a.jsxs)(`span`,{style:{color:`#888`,fontSize:`12px`},children:[Math.round((t+1)/o.length*100),`%`]})]}),(0,a.jsx)(`div`,{style:{width:`100%`,height:`4px`,background:`#333`,borderRadius:`2px`},children:(0,a.jsx)(`div`,{style:{width:`${(t+1)/o.length*100}%`,height:`100%`,background:`#60a5fa`,borderRadius:`2px`,transition:`width 0.3s ease`}})})]}),(0,a.jsx)(`h2`,{id:`tutorial-title`,style:{margin:`0 0 20px 0`,color:`#60a5fa`,fontSize:`24px`},children:l.title}),(0,a.jsx)(`div`,{style:{color:`#ddd`,fontSize:`16px`,lineHeight:`1.6`,whiteSpace:`pre-line`,minHeight:`200px`},children:l.content}),(0,a.jsxs)(`div`,{style:{display:`flex`,justifyContent:`space-between`,marginTop:`30px`},children:[(0,a.jsx)(`button`,{onClick:c,disabled:t===0,style:{padding:`10px 20px`,background:t===0?`#333`:`#555`,color:t===0?`#666`:`#fff`,border:`none`,borderRadius:`6px`,cursor:t===0?`not-allowed`:`pointer`,fontSize:`14px`},children:`Previous`}),(0,a.jsxs)(`div`,{style:{display:`flex`,gap:`10px`},children:[(0,a.jsx)(`button`,{onClick:e,style:{padding:`10px 20px`,background:`#333`,color:`#fff`,border:`none`,borderRadius:`6px`,cursor:`pointer`,fontSize:`14px`},children:`Skip`}),(0,a.jsx)(`button`,{onClick:s,style:{padding:`10px 20px`,background:`#60a5fa`,color:`#000`,border:`none`,borderRadius:`6px`,cursor:`pointer`,fontWeight:`bold`,fontSize:`14px`},children:t===o.length-1?`Get Started!`:`Next`})]})]}),(0,a.jsx)(`div`,{style:{display:`flex`,justifyContent:`center`,gap:`8px`,marginTop:`20px`},children:o.map((e,r)=>(0,a.jsx)(`button`,{onClick:()=>n(r),style:{width:`10px`,height:`10px`,borderRadius:`50%`,border:`none`,background:r===t?`#60a5fa`:`#333`,cursor:`pointer`,padding:0},"aria-label":`Go to step ${r+1}`},r))})]})})}):null};export{s as TutorialPanel};