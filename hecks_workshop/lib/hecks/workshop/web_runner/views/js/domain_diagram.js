// Hecks Web Console — <domain-diagram>
// Force-directed layout with draggable cards, SVG lines, policy flows, services.
// Keyboard: press 0 to reset layout when input is not focused.
import { COLORS, BASE_STYLES, escHtml } from './shared.js';
import { layoutGraph, edgePoint } from './graph_layout.js';

class DomainDiagram extends HTMLElement {
  constructor() { super(); this.attachShadow({ mode: 'open' }); this._state = null; this._cardEls = {}; this._filter = 'all'; }
  set state(s) { this._state = s; this.render(); }
  set filter(f) { this._filter = f; if (this._svgEl) this._drawLines(this._svgEl, this._container); }
  get filter() { return this._filter; }
  disconnectedCallback() { if (this._keyHandler) document.removeEventListener('keydown', this._keyHandler); }

  render() {
    if (!this._state || !this._state.aggregates.length) return;
    const state = this._state, aggs = state.aggregates;

    this.shadowRoot.innerHTML = `
      <style>
        ${BASE_STYLES}
        :host { display: block; position: relative; overflow: hidden; }
        .container { position: relative; overflow: hidden; transform-origin: top left; }
        svg { position: absolute; inset: 0; width: 100%; height: 100%; pointer-events: none; z-index: 0; }
        .cards { position: relative; z-index: 1; }
        .header { color: ${COLORS.blue}; font-weight: 600; font-size: 14px; margin-bottom: 12px; display: flex; justify-content: space-between; align-items: center; }
        .hint { color: ${COLORS.muted}88; font-size: 10px; background: ${COLORS.panel}cc; border: 1px solid ${COLORS.border}; border-radius: 4px; padding: 2px 8px; }
      </style>
      <div class="header"><span>${escHtml(state.domain_name || 'Domain')} Domain</span><span class="hint">${navigator.platform.indexOf('Mac')>=0?'⌥':'Alt'}+scroll zoom · 0 reset · drag to move</span></div>
      <div class="container"><svg></svg><div class="cards"></div></div>
    `;

    this._container = this.shadowRoot.querySelector('.container');
    this._svgEl = this.shadowRoot.querySelector('svg');
    const container = this._container, svgEl = this._svgEl;
    const cardsEl = this.shadowRoot.querySelector('.cards');
    const W = this.offsetWidth || 700, H = Math.max(this.offsetHeight || 500, 400);
    container.style.minHeight = H + 'px';

    const { nodes: graphNodes, edges: graphEdges } = this._buildGraph(aggs);
    const positions = layoutGraph(graphNodes, graphEdges, W, H);

    this._cardEls = {};
    aggs.forEach(agg => {
      const card = document.createElement('agg-card');
      card.data = agg;
      card.style.cssText = `position:absolute;left:${positions[agg.name].x}px;top:${positions[agg.name].y}px;`;
      this._makeDraggable(card, cardsEl, svgEl, container);
      cardsEl.appendChild(card); this._cardEls[agg.name] = card;
    });

    (state.services || []).forEach((svc, i) => {
      const node = document.createElement('div');
      node.style.cssText = `position:absolute;background:${COLORS.panel}e6;border:1px dashed ${COLORS.cyan};border-radius:12px;padding:4px 10px;font-size:10px;color:${COLORS.cyan};white-space:nowrap;left:${20+i*140}px;top:${H-30}px;`;
      node.textContent = `\u2699 ${svc.name}`;
      node.title = `Service: ${svc.name}${svc.domain ? ` (${svc.domain})` : ''}`;
      cardsEl.appendChild(node);
    });

    // Auto zoom-to-fit
    const allX = Object.values(positions).map(p => p.x), allY = Object.values(positions).map(p => p.y);
    const contentW = Math.max(...allX) - Math.min(...allX) + 200, contentH = Math.max(...allY) - Math.min(...allY) + 120;
    let zoom = Math.min(1, W / contentW, H / contentH);
    const applyZoom = () => { container.style.transform = `scale(${zoom})`; };
    container.addEventListener('wheel', (e) => {
      if (!e.altKey) return; e.preventDefault();
      zoom = Math.max(0.3, Math.min(2, zoom - e.deltaY * 0.001)); applyZoom();
    }, { passive: false });
    // Keyboard: 0 resets layout + zoom
    this._keyHandler = (e) => {
      if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') return;
      if (e.key === '0') {
        zoom = 1; applyZoom();
        const np = layoutGraph(graphNodes, graphEdges, W, H);
        aggs.forEach(a => { const c = this._cardEls[a.name]; if (c) { c.style.left = np[a.name].x+'px'; c.style.top = np[a.name].y+'px'; }});
        this._drawLines(svgEl, container);
      }
    };
    document.addEventListener('keydown', this._keyHandler);
    applyZoom();
    requestAnimationFrame(() => this._drawLines(svgEl, container));
  }

  _buildGraph(aggs) {
    const nodes = aggs.map(a => ({ name: a.name, domain: a.domain }));
    const edges = [], seen = {};
    aggs.forEach(agg => {
      agg.attributes.forEach(a => {
        const m = a.type.match(/(?:reference_to|list_of)\((\w+)\)/);
        if (!m || !aggs.find(x => x.name === m[1])) return;
        const pk = agg.name + '|' + m[1];
        if (!seen[pk]) { seen[pk] = true; edges.push({ from: agg.name, to: m[1] }); }
      });
    });
    return { nodes, edges };
  }

  _makeDraggable(card, cardsEl, svgEl, container) {
    card.addEventListener('mousedown', (e) => {
      if (e.composedPath().some(el => el.classList && (el.classList.contains('dot') || el.classList.contains('ref')))) return;
      const r = card.getBoundingClientRect(), dx = e.clientX - r.left, dy = e.clientY - r.top;
      card.style.zIndex = '20'; card.style.cursor = 'grabbing'; e.preventDefault();
      const onMove = (e2) => {
        const cr = cardsEl.getBoundingClientRect();
        card.style.left = Math.max(0, Math.min(cr.width - 160, e2.clientX - cr.left - dx)) + 'px';
        card.style.top = Math.max(0, Math.min(cr.height - 80, e2.clientY - cr.top - dy)) + 'px';
        this._drawLines(svgEl, container);
      };
      const onUp = () => { card.style.zIndex = ''; card.style.cursor = ''; document.removeEventListener('mousemove', onMove); document.removeEventListener('mouseup', onUp); };
      document.addEventListener('mousemove', onMove);
      document.addEventListener('mouseup', onUp);
    });
  }

  _drawLines(svg, container) {
    svg.innerHTML = '';
    const cr = container.getBoundingClientRect();
    svg.setAttribute('width', container.offsetWidth);
    svg.setAttribute('height', container.offsetHeight);
    if (this._filter === 'all' || this._filter === 'references') this._drawRefLines(svg, cr);
    if (this._filter === 'all' || this._filter === 'policies') this._drawPolicyFlows(svg, cr);
  }

  _drawRefLines(svg, cr) {
    const pairMap = {};
    this._state.aggregates.forEach(agg => {
      agg.attributes.forEach(a => {
        const rm = a.type.match(/reference_to\((\w+)\)/), lm = a.type.match(/list_of\((\w+)\)/);
        const target = rm ? rm[1] : (lm ? lm[1] : null);
        if (!target || !this._cardEls[agg.name] || !this._cardEls[target]) return;
        const key = agg.name + '|' + target;
        if (!pairMap[key]) pairMap[key] = { from: agg.name, to: target, isList: !!lm, names: [] };
        pairMap[key].names.push(a.name.replace(/_id$/, ''));
        if (lm) pairMap[key].isList = true;
      });
    });

    Object.values(pairMap).forEach(edge => {
      const pts = this._edgePair(edge.from, edge.to, cr); if (!pts) return;
      const { x1, y1, x2, y2, angle } = pts;
      this._svgLine(svg, x1, y1, x2, y2, COLORS.orange, edge.isList ? '4,3' : 'none', 0.5);
      this._svgArrow(svg, x2, y2, angle, COLORS.orange, 0.5);
      const mx = (x1+x2)/2, my = (y1+y2)/2;
      if (edge.names.length > 1) {
        const text = this._svgText(svg, mx, my+3, edge.names.length, COLORS.orange, 10, 'bold');
        text.setAttribute('stroke', COLORS.bg); text.setAttribute('stroke-width', '3'); text.setAttribute('paint-order', 'stroke');
        const title = document.createElementNS('http://www.w3.org/2000/svg', 'title');
        title.textContent = edge.names.join(', '); text.appendChild(title);
      } else if (edge.names[0].toLowerCase() !== edge.to.toLowerCase()) {
        this._svgText(svg, mx, my-4, edge.names[0], COLORS.orange, 9);
      }
    });
  }

  _drawPolicyFlows(svg, cr) {
    (this._state.policy_flows || []).forEach(flow => {
      const pts = this._edgePair(flow.from, flow.to, cr); if (!pts) return;
      const mx = (pts.x1+pts.x2)/2, my = (pts.y1+pts.y2)/2 - 20;
      const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
      path.setAttribute('d', `M${pts.x1},${pts.y1} Q${mx},${my} ${pts.x2},${pts.y2}`);
      path.setAttribute('stroke', COLORS.red); path.setAttribute('fill', 'none');
      path.setAttribute('stroke-width', '1.8'); path.setAttribute('stroke-dasharray', '6,3');
      path.setAttribute('opacity', '0.8');
      svg.appendChild(path);
      this._svgText(svg, mx, my-4, flow.event || flow.policy, COLORS.red, 8);
    });
  }

  _edgePair(fromName, toName, cr) {
    const fEl = this._cardEls[fromName], tEl = this._cardEls[toName];
    if (!fEl || !tEl) return null;
    const rect = (el) => { const inner = el.shadowRoot?.querySelector('.card'); return inner ? inner.getBoundingClientRect() : el.getBoundingClientRect(); };
    const f = rect(fEl), t = rect(tEl), pad = 6;
    const cx1 = f.left+f.width/2-cr.left, cy1 = f.top+f.height/2-cr.top;
    const cx2 = t.left+t.width/2-cr.left, cy2 = t.top+t.height/2-cr.top;
    const p1 = edgePoint(cx1, cy1, f.width/2+pad, f.height/2+pad, cx2, cy2);
    const p2 = edgePoint(cx2, cy2, t.width/2+pad, t.height/2+pad, cx1, cy1);
    return { x1: p1.x, y1: p1.y, x2: p2.x, y2: p2.y, angle: Math.atan2(p2.y-p1.y, p2.x-p1.x) };
  }

  _svgLine(svg, x1, y1, x2, y2, color, dash, opacity) {
    const l = document.createElementNS('http://www.w3.org/2000/svg', 'line');
    l.setAttribute('x1',x1); l.setAttribute('y1',y1); l.setAttribute('x2',x2); l.setAttribute('y2',y2);
    l.setAttribute('stroke', color); l.setAttribute('stroke-width','1.5'); l.setAttribute('stroke-dasharray', dash); l.setAttribute('opacity', opacity || 0.6);
    svg.appendChild(l); return l;
  }

  _svgArrow(svg, x, y, angle, color, opacity) {
    const al = 8, pa = Math.PI/6;
    const arrow = document.createElementNS('http://www.w3.org/2000/svg', 'polygon');
    arrow.setAttribute('points', `${x},${y} ${x-Math.cos(angle-pa)*al},${y-Math.sin(angle-pa)*al} ${x-Math.cos(angle+pa)*al},${y-Math.sin(angle+pa)*al}`);
    arrow.setAttribute('fill', color); arrow.setAttribute('opacity', opacity || 0.6);
    svg.appendChild(arrow);
  }

  _svgText(svg, x, y, text, color, size, weight) {
    const t = document.createElementNS('http://www.w3.org/2000/svg', 'text');
    t.setAttribute('x', x); t.setAttribute('y', y); t.setAttribute('text-anchor', 'middle');
    t.setAttribute('font-size', size); t.setAttribute('fill', color); t.setAttribute('opacity', '0.7');
    if (weight) t.setAttribute('font-weight', weight);
    t.textContent = text; svg.appendChild(t); return t;
  }

}

customElements.define('domain-diagram', DomainDiagram);
