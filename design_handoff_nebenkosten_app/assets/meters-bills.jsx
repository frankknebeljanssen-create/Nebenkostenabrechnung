// Zähler & Rechnungen screens

function MetersScreen({ scope }) {
  const visible = scope === 'objekt' ? METERS : METERS.filter(m => m.unit_scope === scope || m.unit_scope === 'objekt');
  
  const byMedium = {};
  visible.forEach(m => {
    if (!byMedium[m.medium]) byMedium[m.medium] = [];
    byMedium[m.medium].push(m);
  });

  const mediumIcons = {
    'Wärme': 'flame', 'Warmwasser': 'water', 'Kaltwasser': 'water',
    'Allgemeinstrom': 'bolt', 'Gas': 'flame',
  };
  const mediumColors = {
    'Wärme': '#C2610F', 'Warmwasser': '#8C5A3C',
    'Kaltwasser': '#3A6B8C', 'Allgemeinstrom': '#B8841F',
  };

  const openCount = visible.filter(m => m.statusEnd === 'missing').length;

  return (
    <div style={{ padding: '14px 16px 130px', display: 'flex', flexDirection: 'column', gap: 16 }}>
      {openCount > 0 && (
        <div style={{
          display: 'flex', gap: 10, alignItems: 'center',
          padding: '12px 14px', background: TOKENS.statusWarnSoft,
          borderRadius: 12, border: `0.5px solid ${TOKENS.statusWarn}33`,
        }}>
          <Icon name="warn" size={18} color={TOKENS.statusWarn} stroke={1.8} />
          <div style={{ flex: 1 }}>
            <div style={{
              fontFamily: TOKENS.fontSans, fontSize: 13, fontWeight: 600, color: TOKENS.statusWarn,
            }}>{openCount} Endstand{openCount > 1 ? 'e' : ''} fehlt{openCount > 1 ? 'en' : ''}</div>
          </div>
          <button style={{
            padding: '6px 10px', background: TOKENS.statusWarn, color: 'white',
            border: 'none', borderRadius: 8, cursor: 'pointer',
            fontFamily: TOKENS.fontSans, fontSize: 12, fontWeight: 600,
          }}>Jetzt erfassen</button>
        </div>
      )}

      {Object.entries(byMedium).map(([medium, meters]) => (
        <div key={medium}>
          <div style={{
            display: 'flex', alignItems: 'center', gap: 8,
            padding: '0 4px 8px',
          }}>
            <Icon name={mediumIcons[medium] || 'gauge'} size={15} color={mediumColors[medium] || TOKENS.textSecondary} stroke={1.8} />
            <span style={{
              fontFamily: TOKENS.fontSans, fontSize: 12, fontWeight: 600,
              color: TOKENS.textTertiary, letterSpacing: 0.6, textTransform: 'uppercase',
            }}>{medium}</span>
            <span style={{
              fontFamily: TOKENS.fontMono, fontSize: 11, color: TOKENS.textQuaternary,
            }}>{meters.length}</span>
          </div>
          <div style={{
            background: TOKENS.bgSurface,
            border: `0.5px solid ${TOKENS.separator}`,
            borderRadius: 14, overflow: 'hidden',
          }}>
            {meters.map((m, i) => (
              <MeterRow key={m.id} m={m} last={i === meters.length - 1} />
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}

function MeterRow({ m, last }) {
  const uc = UNIT_COLOR[m.unit_scope] || UNIT_COLOR.objekt;
  const delta = m.statusEnd === 'ok' 
    ? parseFloat(m.numEnd.replace('.', '').replace(',', '.')) - parseFloat(m.numStart.replace('.', '').replace(',', '.'))
    : null;
  return (
    <div style={{
      padding: '12px 14px',
      borderBottom: last ? 'none' : `0.5px solid ${TOKENS.separator}`,
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 8 }}>
        <div style={{
          padding: '2px 6px', borderRadius: 4, background: uc.soft, color: uc.fg,
          fontFamily: TOKENS.fontSans, fontSize: 10, fontWeight: 600, letterSpacing: 0.3,
        }}>{m.unit_scope === 'objekt' ? 'HAUS' : m.unit_scope.toUpperCase()}</div>
        <span style={{
          fontFamily: TOKENS.fontSans, fontSize: 14, fontWeight: 500, color: TOKENS.text, flex: 1,
        }}>{m.location}</span>
        <span style={{
          fontFamily: TOKENS.fontSans, fontSize: 11, color: TOKENS.textTertiary,
        }}>{m.type}</span>
      </div>
      <div style={{ display: 'flex', gap: 10, alignItems: 'stretch' }}>
        <MeterReading label="Anfang" date={m.dateStart} value={m.numStart} unit={m.unitMeas} status={m.statusStart} />
        <div style={{
          display: 'flex', alignItems: 'center', paddingTop: 18,
          fontFamily: TOKENS.fontMono, fontSize: 12, color: TOKENS.textTertiary,
        }}>→</div>
        <MeterReading label="Ende" date={m.dateEnd} value={m.numEnd} unit={m.unitMeas} status={m.statusEnd} />
        <div style={{
          minWidth: 70, textAlign: 'right', display: 'flex', flexDirection: 'column',
          justifyContent: 'flex-end',
        }}>
          <div style={{
            fontFamily: TOKENS.fontSans, fontSize: 10, color: TOKENS.textTertiary,
            letterSpacing: 0.3, marginBottom: 2,
          }}>VERBRAUCH</div>
          <div style={{
            fontFamily: TOKENS.fontMono, fontSize: 14, fontWeight: 600,
            color: delta !== null ? TOKENS.text : TOKENS.textQuaternary,
          }}>
            {delta !== null ? `${fmtNumber(delta, delta < 10 ? 1 : 0)}` : '—'}
          </div>
          <div style={{
            fontFamily: TOKENS.fontMono, fontSize: 10, color: TOKENS.textTertiary,
          }}>{m.unitMeas}</div>
        </div>
      </div>
    </div>
  );
}

function MeterReading({ label, date, value, unit, status }) {
  return (
    <div style={{ flex: 1 }}>
      <div style={{
        display: 'flex', alignItems: 'center', gap: 5,
        marginBottom: 3,
      }}>
        <StatusDot status={status === 'ok' ? 'ok' : 'error'} size={6} />
        <span style={{
          fontFamily: TOKENS.fontSans, fontSize: 10, color: TOKENS.textTertiary,
          letterSpacing: 0.3, textTransform: 'uppercase',
        }}>{label}</span>
        {date && <span style={{
          fontFamily: TOKENS.fontMono, fontSize: 10, color: TOKENS.textTertiary,
        }}>{date.slice(0,5)}</span>}
      </div>
      <div style={{
        fontFamily: TOKENS.fontMono, fontSize: 14, fontWeight: 600,
        color: status === 'ok' ? TOKENS.text : TOKENS.statusError,
      }}>
        {value || '— — —'}
      </div>
    </div>
  );
}

// ─── Bills screen ───────────────────────────────────────────
function BillsScreen({ scope }) {
  const [openSections, setOpenSections] = useState(() => {
    const s = {};
    BETRKV_ORDER.forEach(k => { s[k] = true; });
    return s;
  });
  const [search, setSearch] = useState('');

  const filtered = BILLS.filter(b => 
    !search || b.issuer.toLowerCase().includes(search.toLowerCase()) ||
    b.category.toLowerCase().includes(search.toLowerCase())
  );

  const byCategory = {};
  filtered.forEach(b => {
    if (!byCategory[b.category]) byCategory[b.category] = [];
    byCategory[b.category].push(b);
  });

  const ordered = BETRKV_ORDER.filter(k => byCategory[k]);

  return (
    <div style={{ padding: '12px 16px 130px', display: 'flex', flexDirection: 'column', gap: 12 }}>
      {/* Search */}
      <div style={{
        display: 'flex', alignItems: 'center', gap: 8,
        background: 'rgba(60,50,40,0.06)', borderRadius: 10,
        padding: '8px 12px',
      }}>
        <Icon name="search" size={15} color={TOKENS.textTertiary} stroke={2} />
        <input value={search} onChange={e => setSearch(e.target.value)}
          placeholder="Rechnung oder Versorger suchen…"
          style={{
            flex: 1, background: 'transparent', border: 'none', outline: 'none',
            fontFamily: TOKENS.fontSans, fontSize: 14, color: TOKENS.text,
          }} />
      </div>

      {ordered.map(cat => {
        const bills = byCategory[cat];
        const isOpen = openSections[cat];
        const total = bills.reduce((s, b) => s + b.amount, 0);
        const nonUmlage = cat.includes('nicht umlagefähig');
        
        return (
          <div key={cat}>
            <button onClick={() => setOpenSections(s => ({...s, [cat]: !s[cat]}))} style={{
              display: 'flex', alignItems: 'center', gap: 8,
              width: '100%', padding: '8px 4px',
              background: 'transparent', border: 'none', cursor: 'pointer', textAlign: 'left',
            }}>
              <Icon name={isOpen ? 'chevronDown' : 'chevronRight'} size={12} 
                color={TOKENS.textTertiary} stroke={2.2} />
              <span style={{
                flex: 1,
                fontFamily: TOKENS.fontSans, fontSize: 12, fontWeight: 600,
                color: nonUmlage ? TOKENS.textTertiary : TOKENS.textSecondary,
                letterSpacing: 0.5, textTransform: 'uppercase',
              }}>{cat}</span>
              <span style={{
                fontFamily: TOKENS.fontMono, fontSize: 12, fontWeight: 600,
                color: nonUmlage ? TOKENS.textTertiary : TOKENS.text,
              }}>{fmtEuro(total)}</span>
            </button>
            {isOpen && (
              <div style={{
                background: TOKENS.bgSurface,
                border: `0.5px solid ${TOKENS.separator}`,
                borderRadius: 12, overflow: 'hidden',
              }}>
                {bills.map((b, i) => (
                  <BillRow key={b.id} b={b} last={i === bills.length - 1} />
                ))}
              </div>
            )}
          </div>
        );
      })}

      <button style={{
        marginTop: 6, padding: '12px',
        background: 'transparent', color: TOKENS.accent,
        border: `1.5px dashed ${TOKENS.accent}60`, borderRadius: 12,
        fontFamily: TOKENS.fontSans, fontSize: 14, fontWeight: 500,
        cursor: 'pointer',
        display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
      }}>
        <Icon name="plus" size={16} color={TOKENS.accent} stroke={2} />
        Rechnung hinzufügen
      </button>
    </div>
  );
}

function BillRow({ b, last }) {
  const statusLabel = {
    validated: 'Validiert', suggested: 'KI-Vorschlag', raw: 'Roh',
  }[b.confidence];
  const umlageLabel = b.umlage === 'ok' ? 'umlagefähig' : 'privat';
  return (
    <div style={{
      padding: '12px 14px',
      borderBottom: last ? 'none' : `0.5px solid ${TOKENS.separator}`,
    }}>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 10, marginBottom: 4 }}>
        <span style={{
          flex: 1,
          fontFamily: TOKENS.fontSans, fontSize: 15, fontWeight: 500, color: TOKENS.text,
        }}>{b.issuer}</span>
        <span style={{
          fontFamily: TOKENS.fontMono, fontSize: 15, fontWeight: 600,
          color: b.umlage === 'ok' ? TOKENS.text : TOKENS.textTertiary,
          textDecoration: b.umlage === 'ok' ? 'none' : 'line-through',
        }}>{fmtEuro(b.amount)}</span>
      </div>
      <div style={{
        display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap',
      }}>
        <span style={{
          fontFamily: TOKENS.fontMono, fontSize: 11, color: TOKENS.textTertiary,
        }}>{b.date} · {b.period}</span>
        <StatusPill status={b.confidence} label={statusLabel} />
        {b.umlage === 'no' && <StatusPill status="muted" label={umlageLabel} />}
      </div>
    </div>
  );
}

Object.assign(window, { MetersScreen, BillsScreen });
