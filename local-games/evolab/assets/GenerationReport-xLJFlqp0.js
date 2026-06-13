import{r as e}from"./rolldown-runtime-QTnfLwEv.js";import{i as t,n,t as r}from"./vendor-react-BXfsOOax.js";var i=e(t(),1),a=n(),o=({generation:e,survivalTime:t,resourcesCollected:n,mutations:o,dnaPointsEarned:s,onContinue:c})=>(i.useEffect(()=>{let e=e=>{(e.key===`Escape`||e.key===`Enter`)&&(e.preventDefault(),c())};return document.addEventListener(`keydown`,e),()=>document.removeEventListener(`keydown`,e)},[c]),(0,a.jsxs)(`div`,{className:`modal-overlay`,role:`dialog`,"aria-modal":`true`,"aria-labelledby":`generation-report-title`,children:[(0,a.jsx)(r,{returnFocus:!0,children:(0,a.jsxs)(`div`,{className:`generation-report`,children:[(0,a.jsxs)(`h2`,{id:`generation-report-title`,className:`report-title`,children:[`🎉 Generation `,e-1,` Complete!`]}),(0,a.jsxs)(`div`,{className:`report-content`,children:[(0,a.jsxs)(`div`,{className:`stat-grid`,children:[(0,a.jsxs)(`div`,{className:`stat-card`,children:[(0,a.jsx)(`div`,{className:`stat-label`,children:`Survival Time`}),(0,a.jsx)(`div`,{className:`stat-value`,children:(e=>`${Math.floor(e/60)}m ${Math.floor(e%60)}s`)(t)})]}),(0,a.jsxs)(`div`,{className:`stat-card`,children:[(0,a.jsx)(`div`,{className:`stat-label`,children:`Resources Collected`}),(0,a.jsx)(`div`,{className:`stat-value`,children:n})]}),(0,a.jsxs)(`div`,{className:`stat-card`,children:[(0,a.jsx)(`div`,{className:`stat-label`,children:`DNA Points Earned`}),(0,a.jsxs)(`div`,{className:`stat-value`,children:[`+`,s.toFixed(1)]})]})]}),o.length>0&&(0,a.jsxs)(`div`,{className:`mutations-section`,children:[(0,a.jsx)(`h3`,{children:`🧬 New Mutations`}),(0,a.jsx)(`div`,{className:`mutations-list`,children:o.map((e,t)=>(0,a.jsx)(`div`,{className:`mutation-item`,children:e},t))})]}),(0,a.jsxs)(`div`,{className:`generation-info`,children:[(0,a.jsxs)(`p`,{children:[`You are now entering `,(0,a.jsxs)(`strong`,{children:[`Generation `,e]})]}),(0,a.jsx)(`p`,{children:`Use your DNA points to evolve and adapt to your environment!`})]})]}),(0,a.jsx)(`div`,{className:`report-footer`,children:(0,a.jsx)(`button`,{onClick:c,className:`btn btn-primary btn-large`,children:`Continue to Next Generation →`})})]})}),(0,a.jsx)(`style`,{children:`
        .modal-overlay {
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

        .generation-report {
          background: linear-gradient(135deg, #1a1e2e 0%, #2d3548 100%);
          border-radius: 16px;
          width: 90%;
          max-width: 600px;
          padding: 40px;
          box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5);
          border: 2px solid #4caf50;
        }

        .report-title {
          text-align: center;
          color: #4caf50;
          margin: 0 0 30px 0;
          font-size: 32px;
        }

        .report-content {
          margin-bottom: 30px;
        }

        .stat-grid {
          display: grid;
          grid-template-columns: repeat(3, 1fr);
          gap: 15px;
          margin-bottom: 30px;
        }

        .stat-card {
          background: rgba(255, 255, 255, 0.05);
          padding: 20px;
          border-radius: 8px;
          text-align: center;
        }

        .stat-label {
          color: #aaa;
          font-size: 12px;
          margin-bottom: 8px;
          text-transform: uppercase;
        }

        .stat-value {
          color: #4caf50;
          font-size: 24px;
          font-weight: bold;
          font-family: 'Courier New', monospace;
        }

        .mutations-section {
          background: rgba(76, 175, 80, 0.1);
          padding: 20px;
          border-radius: 8px;
          margin-bottom: 20px;
        }

        .mutations-section h3 {
          color: #4caf50;
          margin: 0 0 15px 0;
          font-size: 18px;
        }

        .mutations-list {
          display: flex;
          flex-wrap: wrap;
          gap: 8px;
        }

        .mutation-item {
          background: rgba(76, 175, 80, 0.2);
          padding: 6px 12px;
          border-radius: 4px;
          font-size: 13px;
          color: #fff;
          font-family: 'Courier New', monospace;
        }

        .generation-info {
          text-align: center;
          color: #ccc;
          font-size: 14px;
        }

        .generation-info p {
          margin: 8px 0;
        }

        .generation-info strong {
          color: #4caf50;
        }

        .report-footer {
          text-align: center;
        }

        .btn-large {
          padding: 16px 32px;
          font-size: 16px;
        }
      `})]}));export{o as GenerationReport};