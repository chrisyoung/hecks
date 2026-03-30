// Hecks Web Console — Web Components
// Shadow DOM for encapsulation, slots for composition, custom events for communication.

const COLORS = {
  bg: '#0d1117', panel: '#161b22', border: '#30363d', muted: '#484f58', text: '#c9d1d9',
  blue: '#58a6ff', green: '#7ee787', orange: '#f0883e', purple: '#d2a8ff',
  red: '#f85149', yellow: '#d29922', cyan: '#79c0ff'
};

const SECTION_COLORS = {
  attributes: COLORS.green, references: COLORS.orange, commands: COLORS.blue,
  events: COLORS.purple, policies: COLORS.red, queries: COLORS.cyan,
  specifications: COLORS.yellow, value_objects: COLORS.orange, entities: COLORS.orange
};

const BASE_STYLES = `
  * { margin: 0; padding: 0; box-sizing: border-box; }
  :host { display: block; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; color: ${COLORS.text}; font-size: 12px; }
`;

// ─── <section-panel> ────────────────────────────────────────
// Collapsible color-coded section. Used in cards, sidebar, and terminal.
//
// Attributes: label, color, collapsed
// Slots: default (items)
// Events: section-toggle
class SectionPanel extends HTMLElement {
  static get observedAttributes() { return ['label', 'color', 'collapsed']; }

  constructor() {
    super();
    this.attachShadow({ mode: 'open' });
  }

  connectedCallback() { this.render(); }
  attributeChangedCallback() { this.render(); }

  get isCollapsed() { return this.hasAttribute('collapsed'); }

  render() {
    const label = this.getAttribute('label') || '';
    const color = this.getAttribute('color') || COLORS.blue;
    const collapsed = this.isCollapsed;

    this.shadowRoot.innerHTML = `
      <style>
        ${BASE_STYLES}
        .header {
          font-size: 10px; text-transform: uppercase; letter-spacing: 0.5px;
          padding-left: 8px; border-left: 2px solid ${color}; color: ${color};
          cursor: pointer; user-select: none; display: flex; align-items: center; gap: 4px;
          margin-top: 8px; margin-bottom: 3px;
        }
        .header:hover .chevron { opacity: 1; }
        .chevron {
          font-size: 8px; transition: transform 0.2s, opacity 0.2s;
          opacity: ${collapsed ? '0.5' : '1'};
          transform: ${collapsed ? 'none' : 'rotate(90deg)'};
        }
        .items { display: ${collapsed ? 'none' : 'block'}; margin-left: 10px; }
      </style>
      <div class="header" part="header">
        <span class="chevron">&#9654;</span>
        <span>${label}</span>
      </div>
      <div class="items" part="items">
        <slot></slot>
      </div>
    `;

    this.shadowRoot.querySelector('.header').addEventListener('click', () => {
      if (this.isCollapsed) {
        this.removeAttribute('collapsed');
      } else {
        this.setAttribute('collapsed', '');
      }
      this.dispatchEvent(new CustomEvent('section-toggle', {
        bubbles: true, detail: { label, collapsed: this.isCollapsed }
      }));
    });
  }
}

// ─── <agg-item> ─────────────────────────────────────────────
// Single item row with optional remove (×) and type display.
//
// Attributes: name, type, removable, nav-target
// Events: item-remove, item-navigate
class AggItem extends HTMLElement {
  static get observedAttributes() { return ['name', 'type', 'removable', 'nav-target']; }

  constructor() {
    super();
    this.attachShadow({ mode: 'open' });
  }

  connectedCallback() { this.render(); }
  attributeChangedCallback() { this.render(); }

  render() {
    const name = this.getAttribute('name') || '';
    const type = this.getAttribute('type') || '';
    const removable = this.hasAttribute('removable');
    const navTarget = this.getAttribute('nav-target');
    const isRef = !!navTarget;

    this.shadowRoot.innerHTML = `
      <style>
        ${BASE_STYLES}
        :host { display: block; line-height: 1.8; }
        .row { display: flex; align-items: center; gap: 4px; }
        .row:hover .remove { opacity: 1; }
        .name { color: ${COLORS.text}; }
        .type { color: ${COLORS.muted}; }
        .ref { color: ${COLORS.orange}; cursor: pointer; }
        .ref:hover { text-decoration: underline; }
        .remove { color: ${COLORS.red}; cursor: pointer; font-size: 11px; opacity: 0; transition: opacity 0.2s; margin-left: 2px; }
        .deleted { text-decoration: line-through; opacity: 0.5; }
        .undo { color: ${COLORS.blue}; cursor: pointer; font-size: 11px; margin-left: 4px; }
      </style>
      <div class="row">
        ${isRef
          ? `<span class="ref">${this._esc(name.replace(/_id$/, ''))} → ${this._esc(navTarget)}</span>`
          : `<span class="name">${this._esc(name)}</span><span class="type">${this._esc(type)}</span>`
        }
        ${removable ? '<span class="remove">×</span>' : ''}
      </div>
    `;

    if (isRef) {
      this.shadowRoot.querySelector('.ref')?.addEventListener('click', (e) => {
        e.stopPropagation();
        this.dispatchEvent(new CustomEvent('item-navigate', {
          bubbles: true, composed: true, detail: { target: navTarget }
        }));
      });
    }

    if (removable) {
      this.shadowRoot.querySelector('.remove')?.addEventListener('click', (e) => {
        e.stopPropagation();
        const row = this.shadowRoot.querySelector('.row');
        row.classList.add('deleted');
        this.shadowRoot.querySelector('.remove').style.display = 'none';
        const undo = document.createElement('span');
        undo.className = 'undo';
        undo.textContent = '(undo)';
        undo.addEventListener('click', (e2) => {
          e2.stopPropagation();
          this.dispatchEvent(new CustomEvent('item-undo', {
            bubbles: true, composed: true, detail: { name }
          }));
        });
        row.appendChild(undo);
        this.dispatchEvent(new CustomEvent('item-remove', {
          bubbles: true, composed: true, detail: { name, type }
        }));
      });
    }
  }

  _esc(s) {
    const d = document.createElement('span');
    d.textContent = s;
    return d.innerHTML;
  }
}

// ─── <agg-card> ─────────────────────────────────────────────
// Compact aggregate card for the domain diagram.
// Shows name + colored dot tabs. Click dot to expand section.
//
// Properties: .data (aggregate object from state)
// Events: card-hover, item-navigate, item-remove
class AggCard extends HTMLElement {
  constructor() {
    super();
    this.attachShadow({ mode: 'open' });
    this._data = null;
  }

  set data(agg) {
    this._data = agg;
    this.render();
  }

  get data() { return this._data; }

  render() {
    if (!this._data) return;
    const agg = this._data;

    const sections = this._buildSections(agg);

    this.shadowRoot.innerHTML = `
      <style>
        ${BASE_STYLES}
        :host { display: block; }
        .card { background: ${COLORS.panel}; border: 1px solid ${COLORS.border}; border-radius: 6px; padding: 8px; min-width: 120px; max-width: 180px; }
        .name { color: ${COLORS.orange}; font-weight: 600; font-size: 11px; cursor: pointer; }
        .name:hover { text-decoration: underline; }
        .dots { display: flex; gap: 6px; margin-top: 4px; }
        .dot { width: 16px; height: 16px; border-radius: 50%; display: inline-flex; align-items: center; justify-content: center;
               font-size: 8px; font-weight: bold; color: ${COLORS.bg}; cursor: pointer; transition: transform 0.15s; }
        .dot:hover { transform: scale(1.3); }
        .dot.dim { opacity: 0.3; }
        .detail { margin-top: 6px; }
        .detail-header { font-size: 9px; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 2px; }
        .detail-item { font-size: 10px; line-height: 1.6; color: ${COLORS.text}; }
        .ref { color: ${COLORS.orange}; cursor: pointer; }
        .ref:hover { text-decoration: underline; }
        .collapse { color: ${COLORS.muted}; font-size: 10px; cursor: pointer; text-align: right; margin-top: 4px; }
        .collapse:hover { color: ${COLORS.text}; }
        .card.open { border-bottom-left-radius: 0; border-bottom-right-radius: 0; }
        .dropdown { background: ${COLORS.panel}; border: 1px solid ${COLORS.border}; border-top: none;
                    border-bottom-left-radius: 6px; border-bottom-right-radius: 6px; padding: 8px; }
      </style>
      <div class="card" part="card">
        <div class="name">${this._esc(agg.name)}</div>
        <div class="dots">${sections.map((s, i) =>
          `<span class="dot" data-idx="${i}" style="background:${s.color}" title="${s.key} (${s.items.length})">${s.items.length}</span>`
        ).join('')}</div>
      </div>
      <div class="dropdown" style="display:none"></div>
    `;

    const card = this.shadowRoot.querySelector('.card');
    const dropdown = this.shadowRoot.querySelector('.dropdown');
    const dots = this.shadowRoot.querySelectorAll('.dot');
    let activeIdx = -1;

    // Name click → navigate
    this.shadowRoot.querySelector('.name').addEventListener('click', () => {
      this.dispatchEvent(new CustomEvent('card-select', {
        bubbles: true, composed: true, detail: { name: agg.name }
      }));
    });

    // Dot click → toggle section
    dots.forEach((dot, i) => {
      dot.addEventListener('click', (e) => {
        e.stopPropagation();
        if (activeIdx === i) {
          dropdown.style.display = 'none';
          card.classList.remove('open');
          dots.forEach(d => d.classList.remove('dim'));
          activeIdx = -1;
          return;
        }
        activeIdx = i;
        card.classList.add('open');
        dots.forEach(d => d.classList.add('dim'));
        dot.classList.remove('dim');
        this._renderSection(dropdown, sections[i]);
        dropdown.style.display = 'block';
      });
    });

    // Card click → collapse
    card.addEventListener('click', (e) => {
      if (e.target.closest('.dot') || e.target.closest('.name')) return;
      if (activeIdx >= 0) {
        dropdown.style.display = 'none';
        card.classList.remove('open');
        dots.forEach(d => d.classList.remove('dim'));
        activeIdx = -1;
      }
    });

    // Hover → emit
    this.addEventListener('mouseenter', () => {
      this.dispatchEvent(new CustomEvent('card-hover', {
        bubbles: true, composed: true, detail: { name: agg.name }
      }));
    });
  }

  _renderSection(container, section) {
    let html = `<div class="detail-header" style="color:${section.color}">${section.key}</div>`;
    section.items.forEach(item => {
      html += `<div class="detail-item">${section.render(item)}</div>`;
    });
    html += `<div class="collapse">▲</div>`;
    container.innerHTML = html;

    // Wire ref clicks
    container.querySelectorAll('.ref').forEach(ref => {
      ref.addEventListener('click', (e) => {
        e.stopPropagation();
        this.dispatchEvent(new CustomEvent('item-navigate', {
          bubbles: true, composed: true, detail: { target: ref.dataset.target }
        }));
      });
    });

    // Collapse button
    container.querySelector('.collapse').addEventListener('click', (e) => {
      e.stopPropagation();
      container.style.display = 'none';
      this.shadowRoot.querySelector('.card').classList.remove('open');
      this.shadowRoot.querySelectorAll('.dot').forEach(d => d.classList.remove('dim'));
    });
  }

  _buildSections(agg) {
    const sections = [];
    const attrs = agg.attributes.filter(a => !a.type.match(/reference_to|list_of/));
    const refs = agg.attributes.filter(a => a.type.match(/reference_to|list_of/));

    if (attrs.length) sections.push({
      key: 'attributes', color: COLORS.green, items: attrs,
      render: a => `${this._esc(a.name)} <span style="color:${COLORS.muted}">${this._esc(a.type)}</span>`
    });
    if (refs.length) sections.push({
      key: 'references', color: COLORS.orange, items: refs,
      render: a => {
        const m = a.type.match(/(?:reference_to|list_of)\((\w+)\)/);
        const t = m ? m[1] : '';
        const label = a.name.replace(/_id$/, '');
        return `<span class="ref" data-target="${this._esc(t)}">${this._esc(label)} → ${this._esc(t)}</span>`;
      }
    });
    if (agg.commands.length) sections.push({
      key: 'commands', color: COLORS.blue, items: agg.commands,
      render: c => this._esc(c)
    });
    if (agg.events.length) sections.push({
      key: 'events', color: COLORS.purple, items: agg.events,
      render: e => this._esc(e)
    });
    if (agg.policies?.length) sections.push({
      key: 'policies', color: COLORS.red, items: agg.policies,
      render: p => this._esc(p)
    });
    if (agg.queries?.length) sections.push({
      key: 'queries', color: COLORS.cyan, items: agg.queries,
      render: q => this._esc(q)
    });
    if (agg.specifications?.length) sections.push({
      key: 'specifications', color: COLORS.yellow, items: agg.specifications,
      render: s => this._esc(s)
    });
    return sections;
  }

  _esc(s) {
    const d = document.createElement('span');
    d.textContent = s;
    return d.innerHTML;
  }
}

// ─── <agg-inspector> ────────────────────────────────────────
// Right sidebar detail panel for the active aggregate.
//
// Properties: .data (aggregate object), .state (full domain state)
// Events: item-navigate, item-remove
class AggInspector extends HTMLElement {
  constructor() {
    super();
    this.attachShadow({ mode: 'open' });
    this._data = null;
  }

  set data(agg) {
    this._data = agg;
    this.render();
  }

  render() {
    if (!this._data) {
      this.shadowRoot.innerHTML = '';
      return;
    }
    const agg = this._data;

    this.shadowRoot.innerHTML = `
      <style>
        ${BASE_STYLES}
        .title { color: ${COLORS.orange}; font-size: 11px; text-transform: uppercase; letter-spacing: 1px; margin-bottom: 6px; font-weight: 600; }
      </style>
      <div class="title">${this._esc(agg.name)}</div>
      <div id="sections"></div>
    `;

    const container = this.shadowRoot.getElementById('sections');
    const card = new AggCard();
    // Reuse AggCard's section builder
    const sections = card._buildSections(agg);

    sections.forEach(sec => {
      const panel = document.createElement('section-panel');
      panel.setAttribute('label', sec.key);
      panel.setAttribute('color', sec.color);
      panel.setAttribute('collapsed', '');

      sec.items.forEach(item => {
        const el = document.createElement('agg-item');
        const isRef = sec.key === 'references';
        if (isRef) {
          const m = item.type?.match(/(?:reference_to|list_of)\((\w+)\)/);
          el.setAttribute('name', item.name || item);
          if (m) el.setAttribute('nav-target', m[1]);
        } else {
          el.setAttribute('name', typeof item === 'string' ? item : item.name);
          if (item.type && sec.key === 'attributes') el.setAttribute('type', item.type);
        }
        el.setAttribute('removable', '');
        panel.appendChild(el);
      });

      container.appendChild(panel);
    });
  }

  _esc(s) {
    const d = document.createElement('span');
    d.textContent = s;
    return d.innerHTML;
  }
}

// Register all components
// ─── <domain-diagram> ───────────────────────────────────────
// Full domain diagram with draggable cards and SVG connection lines.
//
// Properties: .state (full domain state object)
// Events: card-hover, card-select, item-navigate (bubble from child cards)
class DomainDiagram extends HTMLElement {
  constructor() {
    super();
    this.attachShadow({ mode: 'open' });
    this._state = null;
    this._cardEls = {};
  }

  set state(s) { this._state = s; this.render(); }

  render() {
    if (!this._state || !this._state.aggregates.length) return;
    const state = this._state;
    const aggs = state.aggregates;

    this.shadowRoot.innerHTML = `
      <style>
        ${BASE_STYLES}
        :host { display: block; position: relative; }
        .container { position: relative; }
        svg { position: absolute; inset: 0; width: 100%; height: 100%; pointer-events: none; z-index: 0; }
        .cards { position: relative; z-index: 1; }
        .header { color: ${COLORS.blue}; font-weight: 600; font-size: 14px; margin-bottom: 12px; }
      </style>
      <div class="header">${this._esc(state.domain_name || 'Domain')} Domain</div>
      <div class="container">
        <svg></svg>
        <div class="cards"></div>
      </div>
    `;

    const container = this.shadowRoot.querySelector('.container');
    const svgEl = this.shadowRoot.querySelector('svg');
    const cardsEl = this.shadowRoot.querySelector('.cards');
    const hostWidth = this.offsetWidth || 700;
    const cardW = 160, cardH = 80, pad = 30;
    const cols = Math.max(2, Math.floor(hostWidth / (cardW + pad)));
    const rows = Math.ceil(aggs.length / cols);
    container.style.minHeight = (rows * (cardH + pad) + pad) + 'px';

    this._cardEls = {};
    aggs.forEach((agg, i) => {
      const card = document.createElement('agg-card');
      card.data = agg;
      card.style.position = 'absolute';
      card.style.left = ((i % cols) * (cardW + pad) + pad) + 'px';
      card.style.top = (Math.floor(i / cols) * (cardH + pad) + pad) + 'px';

      // Drag
      card.addEventListener('mousedown', (e) => {
        if (e.target.closest('.dot') || e.target.closest('.ref') || e.target.closest('.collapse')) return;
        if (e.composedPath().some(el => el.classList && (el.classList.contains('dot') || el.classList.contains('ref')))) return;
        const r = card.getBoundingClientRect();
        const dx = e.clientX - r.left;
        const dy = e.clientY - r.top;
        card.style.zIndex = '20';
        card.style.cursor = 'grabbing';
        e.preventDefault();
        const onMove = (e2) => {
          const cr = cardsEl.getBoundingClientRect();
          card.style.left = (e2.clientX - cr.left - dx) + 'px';
          card.style.top = (e2.clientY - cr.top - dy) + 'px';
          this._drawLines(svgEl, container);
        };
        const onUp = () => {
          card.style.zIndex = '';
          card.style.cursor = '';
          document.removeEventListener('mousemove', onMove);
          document.removeEventListener('mouseup', onUp);
        };
        document.addEventListener('mousemove', onMove);
        document.addEventListener('mouseup', onUp);
      });

      cardsEl.appendChild(card);
      this._cardEls[agg.name] = card;
    });

    requestAnimationFrame(() => this._drawLines(svgEl, container));
  }

  _drawLines(svg, container) {
    svg.innerHTML = '';
    const cr = container.getBoundingClientRect();
    svg.setAttribute('width', container.offsetWidth);
    svg.setAttribute('height', container.offsetHeight);

    this._state.aggregates.forEach(agg => {
      agg.attributes.forEach(a => {
        const rm = a.type.match(/reference_to\((\w+)\)/);
        const lm = a.type.match(/list_of\((\w+)\)/);
        const target = rm ? rm[1] : (lm ? lm[1] : null);
        if (!target || !this._cardEls[agg.name] || !this._cardEls[target]) return;

        const f = this._cardEls[agg.name].getBoundingClientRect();
        const t = this._cardEls[target].getBoundingClientRect();
        let x1 = f.left + f.width/2 - cr.left, y1 = f.top + f.height/2 - cr.top;
        let x2 = t.left + t.width/2 - cr.left, y2 = t.top + t.height/2 - cr.top;
        const angle = Math.atan2(y2-y1, x2-x1);
        x1 += Math.cos(angle)*Math.min(f.width/2, 60);
        y1 += Math.sin(angle)*Math.min(f.height/2, 30);
        x2 -= Math.cos(angle)*Math.min(t.width/2, 60);
        y2 -= Math.sin(angle)*Math.min(t.height/2, 30);

        const line = document.createElementNS('http://www.w3.org/2000/svg', 'line');
        line.setAttribute('x1',x1); line.setAttribute('y1',y1);
        line.setAttribute('x2',x2); line.setAttribute('y2',y2);
        line.setAttribute('stroke', lm ? COLORS.orange : COLORS.blue);
        line.setAttribute('stroke-width','1.5');
        line.setAttribute('stroke-dasharray', lm ? '4,3' : 'none');
        line.setAttribute('opacity','0.5');
        svg.appendChild(line);

        const al = 8, pa = Math.PI/6;
        const arrow = document.createElementNS('http://www.w3.org/2000/svg', 'polygon');
        arrow.setAttribute('points',
          `${x2},${y2} ${x2-Math.cos(angle-pa)*al},${y2-Math.sin(angle-pa)*al} ${x2-Math.cos(angle+pa)*al},${y2-Math.sin(angle+pa)*al}`
        );
        arrow.setAttribute('fill', lm ? COLORS.orange : COLORS.blue);
        arrow.setAttribute('opacity','0.5');
        svg.appendChild(arrow);
      });
    });
  }

  _esc(s) { const d = document.createElement('span'); d.textContent = s; return d.innerHTML; }
}

customElements.define('section-panel', SectionPanel);
customElements.define('agg-item', AggItem);
customElements.define('agg-card', AggCard);
customElements.define('agg-inspector', AggInspector);
customElements.define('domain-diagram', DomainDiagram);
