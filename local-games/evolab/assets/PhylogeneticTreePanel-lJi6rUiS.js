import{r as e}from"./rolldown-runtime-QTnfLwEv.js";import{l as t,n,o as r,s as i}from"./vendor-graphics-Cg4S9coA.js";import{i as a,n as o,t as s}from"./vendor-react-BXfsOOax.js";var c=e(a(),1),l=o(),u=({phylogeneticTree:e,species:a,onClose:o})=>{let u=(0,c.useRef)(null),g=(0,c.useMemo)(()=>[...a].sort((e,t)=>e.isExtinct===t.isExtinct?t.population-e.population:e.isExtinct?1:-1),[a]),_=g.filter(e=>!e.isExtinct).length,v=g.reduce((e,t)=>e+t.population,0);return(0,c.useEffect)(()=>{let e=e=>{e.key===`Escape`&&(e.preventDefault(),o())};return document.addEventListener(`keydown`,e),()=>document.removeEventListener(`keydown`,e)},[o]),(0,c.useEffect)(()=>{if(!u.current||e.length===0)return;t(u.current).selectAll(`*`).remove();let o=new Map(a.map(e=>[e.id,e])),s={top:40,right:140,bottom:40,left:130},c=t(u.current).attr(`width`,860).attr(`height`,420).attr(`viewBox`,`0 0 860 420`).attr(`role`,`img`).attr(`aria-label`,`Phylogenetic tree of player species branches`),l=c.append(`g`).attr(`transform`,`translate(${s.left},${s.top})`);if(e.length===0||!e[0])return;let f=d(e[0]),m=r().size([420-s.top-s.bottom,860-s.left-s.right])(i(f));l.selectAll(`.link`).data(m.links()).enter().append(`path`).attr(`class`,`link`).attr(`d`,n().x(e=>e.y).y(e=>e.x)).style(`fill`,`none`).style(`stroke`,e=>{let t=e.target.data,n=o.get(t.speciesId);return t.isExtinct?`#666`:n?`#${n.color.toString(16).padStart(6,`0`)}`:`#aaa`}).style(`stroke-width`,2.5).style(`stroke-opacity`,.75).style(`stroke-dasharray`,e=>e.target.data.isExtinct?`5,5`:`none`);let h=l.selectAll(`.node`).data(m.descendants()).enter().append(`g`).attr(`class`,`node`).attr(`transform`,e=>`translate(${e.y},${e.x})`);h.append(`circle`).attr(`r`,e=>{let t=e.data,n=o.get(t.speciesId);return n?Math.max(5,Math.min(13,5+n.population*.35)):6}).style(`fill`,e=>{let t=e.data,n=o.get(t.speciesId);return n?`#${n.color.toString(16).padStart(6,`0`)}`:`#999`}).style(`stroke`,`#fff`).style(`stroke-width`,1.5).style(`opacity`,e=>e.data.isExtinct?.4:1),h.append(`text`).attr(`dx`,e=>e.children?-12:12).attr(`dy`,4).style(`text-anchor`,e=>e.children?`end`:`start`).style(`font-size`,`12px`).style(`font-family`,`monospace`).style(`fill`,e=>e.data.isExtinct?`#777`:`#fff`).text(e=>{let t=e.data,n=o.get(t.speciesId);return n?`${p(n.id)} (${n.population})`:t.speciesId}),c.append(`text`).attr(`x`,860/2).attr(`y`,22).attr(`text-anchor`,`middle`).style(`font-size`,`18px`).style(`font-weight`,`bold`).style(`fill`,`#fff`).text(`Player Species Branches`)},[e,a]),(0,l.jsxs)(`div`,{className:`phylo-overlay`,role:`dialog`,"aria-modal":`true`,"aria-labelledby":`phylogenetic-title`,children:[(0,l.jsx)(s,{returnFocus:!0,children:(0,l.jsxs)(`div`,{className:`phylo-panel`,children:[(0,l.jsxs)(`div`,{className:`phylo-header`,children:[(0,l.jsxs)(`div`,{children:[(0,l.jsx)(`h2`,{id:`phylogenetic-title`,children:`Phylogenetic Tree`}),(0,l.jsxs)(`div`,{className:`phylo-summary`,children:[_,` living species ? `,v,` tracked cells`]})]}),(0,l.jsx)(`button`,{className:`close-button`,onClick:o,children:`Close`})]}),e.length>0?(0,l.jsx)(`div`,{className:`tree-scroll`,children:(0,l.jsx)(`svg`,{ref:u})}):(0,l.jsx)(`div`,{className:`empty-state`,children:`Enable Speciation Tracking, then let the population diverge for a few generations.`}),(0,l.jsx)(`div`,{className:`species-guide`,"aria-label":`Species field guide`,children:g.map(e=>(0,l.jsxs)(`div`,{className:e.isExtinct?`species-row extinct`:`species-row`,children:[(0,l.jsxs)(`div`,{className:`species-identity`,children:[(0,l.jsx)(`span`,{className:`species-swatch`,style:{backgroundColor:f(e.color)}}),(0,l.jsxs)(`div`,{children:[(0,l.jsxs)(`div`,{className:`species-name`,children:[p(e.id),` ? `,e.name]}),(0,l.jsxs)(`div`,{className:`species-status`,children:[e.isExtinct?`Extinct`:`Living`,` ? `,h(e.averageTraits)]})]})]}),(0,l.jsxs)(`div`,{className:`species-metric`,children:[(0,l.jsx)(`span`,{children:`Pop`}),e.population]}),(0,l.jsxs)(`div`,{className:`species-metric`,children:[(0,l.jsx)(`span`,{children:`Size`}),m(e.averageTraits.size)]}),(0,l.jsxs)(`div`,{className:`species-metric`,children:[(0,l.jsx)(`span`,{children:`Speed`}),m(e.averageTraits.speed)]}),(0,l.jsxs)(`div`,{className:`species-metric`,children:[(0,l.jsx)(`span`,{children:`Armor`}),m(e.averageTraits.armor)]}),(0,l.jsxs)(`div`,{className:`species-metric`,children:[(0,l.jsx)(`span`,{children:`Agg`}),m(e.averageTraits.aggression)]}),(0,l.jsxs)(`div`,{className:`species-metric`,children:[(0,l.jsx)(`span`,{children:`Fear`}),m(e.averageTraits.fearResponse)]})]},e.id))}),(0,l.jsx)(`div`,{className:`phylo-note`,children:`Species split when a branch becomes genetically different enough. Colors on this panel now match the living cells spawned by that branch.`})]})}),(0,l.jsx)(`style`,{children:`
        .phylo-overlay {
          position: fixed;
          inset: 0;
          z-index: 1000;
          display: flex;
          align-items: center;
          justify-content: center;
          background: rgba(0, 0, 0, 0.78);
          padding: 12px;
        }

        .phylo-panel {
          width: min(1120px, 96vw);
          max-height: 92vh;
          overflow: auto;
          background: #101522;
          border: 2px solid #4caf50;
          border-radius: 8px;
          color: #f4f7fb;
          box-shadow: 0 16px 50px rgba(0, 0, 0, 0.55);
        }

        .phylo-header {
          position: sticky;
          top: 0;
          z-index: 2;
          display: flex;
          align-items: center;
          justify-content: space-between;
          gap: 16px;
          padding: 16px 18px;
          background: #182034;
          border-bottom: 1px solid rgba(76, 175, 80, 0.6);
        }

        .phylo-header h2 {
          margin: 0;
          color: #4ade80;
          font-size: 24px;
        }

        .phylo-summary,
        .species-status,
        .phylo-note,
        .empty-state {
          color: #aab7c8;
          font-size: 13px;
        }

        .close-button {
          border: 0;
          border-radius: 6px;
          padding: 9px 14px;
          background: #ef4444;
          color: #fff;
          font-weight: 700;
          cursor: pointer;
        }

        .tree-scroll {
          overflow-x: auto;
          padding: 14px 18px 4px;
          background: #0b101b;
        }

        .tree-scroll svg {
          max-width: 100%;
          min-width: 760px;
        }

        .empty-state {
          padding: 28px 18px;
        }

        .species-guide {
          display: grid;
          gap: 8px;
          padding: 14px 18px 6px;
        }

        .species-row {
          display: grid;
          grid-template-columns: minmax(220px, 1fr) repeat(6, minmax(58px, 74px));
          gap: 8px;
          align-items: center;
          min-height: 54px;
          padding: 8px 10px;
          border: 1px solid rgba(148, 163, 184, 0.2);
          border-radius: 8px;
          background: rgba(15, 23, 42, 0.76);
        }

        .species-row.extinct {
          opacity: 0.55;
        }

        .species-identity {
          display: flex;
          align-items: center;
          gap: 10px;
          min-width: 0;
        }

        .species-swatch {
          width: 18px;
          height: 18px;
          border-radius: 50%;
          flex: 0 0 auto;
          box-shadow: 0 0 0 2px rgba(255, 255, 255, 0.25);
        }

        .species-name {
          overflow: hidden;
          color: #f8fafc;
          font-weight: 700;
          text-overflow: ellipsis;
          white-space: nowrap;
        }

        .species-metric {
          display: grid;
          gap: 2px;
          justify-items: end;
          font-family: 'Courier New', monospace;
          color: #e5e7eb;
        }

        .species-metric span {
          color: #8fb39b;
          font-size: 11px;
          font-family: Arial, sans-serif;
        }

        .phylo-note {
          padding: 10px 18px 18px;
        }

        @media (max-width: 760px) {
          .phylo-panel {
            max-height: 94vh;
          }

          .phylo-header h2 {
            font-size: 20px;
          }

          .species-row {
            grid-template-columns: minmax(180px, 1fr) repeat(3, minmax(54px, 1fr));
          }

          .species-metric:nth-of-type(n + 5) {
            display: none;
          }
        }
      `})]})};function d(e){return{speciesId:e.speciesId,parentSpeciesId:e.parentSpeciesId,children:e.children.map(d),isExtinct:e.isExtinct}}function f(e){return`#${Math.round(e).toString(16).padStart(6,`0`).slice(-6)}`}function p(e){return`S${e.match(/(\d+)$/)?.[1]??e}`}function m(e){return typeof e!=`number`||!Number.isFinite(e)?`-`:Math.abs(e)>=100?Math.round(e).toString():e.toFixed(1)}function h(e){let t=e.aggression??0,n=e.toxinStrength??0,r=e.photosynthesis??0,i=e.speed??0,a=e.armor??0,o=e.fearResponse??0,s=e.visionRange??0;return t>=7||n>=5?`Predator branch`:r>=.35?`Solar grazer`:a>=7?`Armored grazer`:i>=7&&o>=6?`Skittish sprinter`:s>=280?`Long-range scout`:i>=7?`Fast forager`:`Generalist`}export{u as PhylogeneticTreePanel};