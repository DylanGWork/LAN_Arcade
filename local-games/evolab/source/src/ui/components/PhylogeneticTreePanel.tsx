// Phylogenetic tree visualization panel

import React, { useEffect, useMemo, useRef } from 'react';
import FocusLock from 'react-focus-lock';
import * as d3 from 'd3';
import type { Species, Traits } from '../../types/entities';

interface PhylogeneticNode {
  speciesId: string;
  parentSpeciesId: string | null;
  divergenceTime: number;
  children: PhylogeneticNode[];
  isExtinct: boolean;
}

interface Props {
  phylogeneticTree: PhylogeneticNode[];
  species: Species[];
  onClose: () => void;
}

export const PhylogeneticTreePanel: React.FC<Props> = ({ phylogeneticTree, species, onClose }) => {
  const svgRef = useRef<SVGSVGElement>(null);
  const sortedSpecies = useMemo(() => {
    return [...species].sort((a, b) => {
      if (a.isExtinct !== b.isExtinct) return a.isExtinct ? 1 : -1;
      return b.population - a.population;
    });
  }, [species]);

  const livingCount = sortedSpecies.filter(spec => !spec.isExtinct).length;
  const totalPopulation = sortedSpecies.reduce((sum, spec) => sum + spec.population, 0);

  // Handle ESC key to close
  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        e.preventDefault();
        onClose();
      }
    };

    document.addEventListener('keydown', handleEscape);
    return () => document.removeEventListener('keydown', handleEscape);
  }, [onClose]);

  useEffect(() => {
    if (!svgRef.current || phylogeneticTree.length === 0) return;

    // Clear previous content
    d3.select(svgRef.current).selectAll('*').remove();

    const speciesById = new Map(species.map(spec => [spec.id, spec]));
    const width = 860;
    const height = 420;
    const margin = { top: 40, right: 140, bottom: 40, left: 130 };

    const svg = d3
      .select(svgRef.current)
      .attr('width', width)
      .attr('height', height)
      .attr('viewBox', `0 0 ${width} ${height}`)
      .attr('role', 'img')
      .attr('aria-label', 'Phylogenetic tree of player species branches');

    const g = svg.append('g').attr('transform', `translate(${margin.left},${margin.top})`);

    // Convert tree to D3 hierarchy
    if (phylogeneticTree.length === 0 || !phylogeneticTree[0]) return;
    const root = convertToD3Hierarchy(phylogeneticTree[0]);

    // Create tree layout
    const treeLayout = d3.tree<HierarchyNode>()
      .size([height - margin.top - margin.bottom, width - margin.left - margin.right]);

    const treeData = treeLayout(d3.hierarchy(root));

    // Draw links (branches)
    g.selectAll('.link')
      .data(treeData.links())
      .enter()
      .append('path')
      .attr('class', 'link')
      .attr('d', d3.linkHorizontal<any, any>()
        .x((d: any) => d.y)
        .y((d: any) => d.x)
      )
      .style('fill', 'none')
      .style('stroke', (d: any) => {
        const node = d.target.data as HierarchyNode;
        const spec = speciesById.get(node.speciesId);
        return node.isExtinct ? '#666' : spec ? `#${spec.color.toString(16).padStart(6, '0')}` : '#aaa';
      })
      .style('stroke-width', 2.5)
      .style('stroke-opacity', 0.75)
      .style('stroke-dasharray', (d: any) => {
        const node = d.target.data as HierarchyNode;
        return node.isExtinct ? '5,5' : 'none';
      });

    // Draw nodes
    const nodes = g.selectAll('.node')
      .data(treeData.descendants())
      .enter()
      .append('g')
      .attr('class', 'node')
      .attr('transform', (d: any) => `translate(${d.y},${d.x})`);

    // Node circles
    nodes
      .append('circle')
      .attr('r', (d: any) => {
        const node = d.data as HierarchyNode;
        const spec = speciesById.get(node.speciesId);
        return spec ? Math.max(5, Math.min(13, 5 + spec.population * 0.35)) : 6;
      })
      .style('fill', (d: any) => {
        const node = d.data as HierarchyNode;
        const spec = speciesById.get(node.speciesId);
        return spec ? `#${spec.color.toString(16).padStart(6, '0')}` : '#999';
      })
      .style('stroke', '#fff')
      .style('stroke-width', 1.5)
      .style('opacity', (d: any) => {
        const node = d.data as HierarchyNode;
        return node.isExtinct ? 0.4 : 1;
      });

    // Node labels
    nodes
      .append('text')
      .attr('dx', (d: any) => d.children ? -12 : 12)
      .attr('dy', 4)
      .style('text-anchor', (d: any) => d.children ? 'end' : 'start')
      .style('font-size', '12px')
      .style('font-family', 'monospace')
      .style('fill', (d: any) => {
        const node = d.data as HierarchyNode;
        return node.isExtinct ? '#777' : '#fff';
      })
      .text((d: any) => {
        const node = d.data as HierarchyNode;
        const spec = speciesById.get(node.speciesId);
        return spec ? `${getSpeciesCode(spec.id)} (${spec.population})` : node.speciesId;
      });

    // Title
    svg
      .append('text')
      .attr('x', width / 2)
      .attr('y', 22)
      .attr('text-anchor', 'middle')
      .style('font-size', '18px')
      .style('font-weight', 'bold')
      .style('fill', '#fff')
      .text('Player Species Branches');
  }, [phylogeneticTree, species]);

  return (
    <div className="phylo-overlay" role="dialog" aria-modal="true" aria-labelledby="phylogenetic-title">
      <FocusLock returnFocus>
        <div className="phylo-panel">
          <div className="phylo-header">
            <div>
              <h2 id="phylogenetic-title">Phylogenetic Tree</h2>
              <div className="phylo-summary">
                {livingCount} living species ? {totalPopulation} tracked cells
              </div>
            </div>
            <button className="close-button" onClick={onClose}>Close</button>
          </div>

          {phylogeneticTree.length > 0 ? (
            <div className="tree-scroll">
              <svg ref={svgRef} />
            </div>
          ) : (
            <div className="empty-state">Enable Speciation Tracking, then let the population diverge for a few generations.</div>
          )}

          <div className="species-guide" aria-label="Species field guide">
            {sortedSpecies.map(spec => (
              <div className={spec.isExtinct ? 'species-row extinct' : 'species-row'} key={spec.id}>
                <div className="species-identity">
                  <span className="species-swatch" style={{ backgroundColor: toHex(spec.color) }} />
                  <div>
                    <div className="species-name">{getSpeciesCode(spec.id)} ? {spec.name}</div>
                    <div className="species-status">{spec.isExtinct ? 'Extinct' : 'Living'} ? {getNiche(spec.averageTraits)}</div>
                  </div>
                </div>
                <div className="species-metric"><span>Pop</span>{spec.population}</div>
                <div className="species-metric"><span>Size</span>{formatTrait(spec.averageTraits.size)}</div>
                <div className="species-metric"><span>Speed</span>{formatTrait(spec.averageTraits.speed)}</div>
                <div className="species-metric"><span>Armor</span>{formatTrait(spec.averageTraits.armor)}</div>
                <div className="species-metric"><span>Agg</span>{formatTrait(spec.averageTraits.aggression)}</div>
                <div className="species-metric"><span>Fear</span>{formatTrait(spec.averageTraits.fearResponse)}</div>
              </div>
            ))}
          </div>

          <div className="phylo-note">
            Species split when a branch becomes genetically different enough. Colors on this panel now match the living cells spawned by that branch.
          </div>
        </div>
      </FocusLock>
      <style>{`
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
      `}</style>
    </div>
  );
};

// Helper types and functions
interface HierarchyNode {
  speciesId: string;
  parentSpeciesId: string | null;
  children: HierarchyNode[];
  isExtinct: boolean;
}

function convertToD3Hierarchy(node: PhylogeneticNode): HierarchyNode {
  return {
    speciesId: node.speciesId,
    parentSpeciesId: node.parentSpeciesId,
    children: node.children.map(convertToD3Hierarchy),
    isExtinct: node.isExtinct,
  };
}

function toHex(color: number): string {
  return `#${Math.round(color).toString(16).padStart(6, '0').slice(-6)}`;
}

function getSpeciesCode(speciesId: string): string {
  const suffix = speciesId.match(/(\d+)$/)?.[1] ?? speciesId;
  return `S${suffix}`;
}

function formatTrait(value?: number): string {
  if (typeof value !== 'number' || !Number.isFinite(value)) return '-';
  if (Math.abs(value) >= 100) return Math.round(value).toString();
  return value.toFixed(1);
}

function getNiche(traits: Partial<Traits>): string {
  const aggression = traits.aggression ?? 0;
  const toxin = traits.toxinStrength ?? 0;
  const photosynthesis = traits.photosynthesis ?? 0;
  const speed = traits.speed ?? 0;
  const armor = traits.armor ?? 0;
  const fear = traits.fearResponse ?? 0;
  const vision = traits.visionRange ?? 0;

  if (aggression >= 7 || toxin >= 5) return 'Predator branch';
  if (photosynthesis >= 0.35) return 'Solar grazer';
  if (armor >= 7) return 'Armored grazer';
  if (speed >= 7 && fear >= 6) return 'Skittish sprinter';
  if (vision >= 280) return 'Long-range scout';
  if (speed >= 7) return 'Fast forager';
  return 'Generalist';
}
