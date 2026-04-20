// Shared shell: nav bar with scope switcher, tab bar, scope indicator strip

const { useState, useEffect, useRef, Fragment } = React;

// ─── Scope switcher navbar ───────────────────────────────────
function AppNavBar({ title, scope, onOpenScope, rightAction, compact, subtitle }) {
  return (
    <div style={{
      paddingTop: 54,
      paddingBottom: compact ? 6 : 10,
      background: TOKENS.bgApp,
      position: 'relative',
      zIndex: 5,
    }}>
      <div style={{
        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        padding: '0 16px', minHeight: 32, gap: 8,
      }}>
        <button onClick={onOpenScope} style={{
          display: 'flex', alignItems: 'center', gap: 5, flexShrink: 0,
          background: 'transparent', border: 'none', padding: '4px 0',
          fontFamily: TOKENS.fontSans, fontSize: 14, fontWeight: 500,
          color: TOKENS.textSecondary, cursor: 'pointer', whiteSpace: 'nowrap',
        }}>
          <Icon name="building" size={13} color={TOKENS.textSecondary} stroke={1.8} />
          <span style={{ whiteSpace: 'nowrap' }}>{OBJEKT.address}</span>
          <Icon name="chevronDown" size={12} color={TOKENS.textTertiary} stroke={2} />
        </button>
        <div style={{ flexShrink: 0, display: 'flex', alignItems: 'center' }}>{rightAction}</div>
      </div>
      <div style={{
        padding: compact ? '4px 16px 0' : '6px 16px 0',
        fontFamily: TOKENS.fontSans,
        fontSize: compact ? 26 : 30, fontWeight: 600, lineHeight: 1.1,
        color: TOKENS.text, letterSpacing: -0.6,
      }}>{title}</div>
      {subtitle && (
        <div style={{
          padding: '2px 16px 0',
          fontFamily: TOKENS.fontSans, fontSize: 13,
          color: TOKENS.textSecondary, letterSpacing: -0.1,
        }}>{subtitle}</div>
      )}
    </div>
  );
}

// ─── Scope indicator strip (~32pt) ──────────────────────────
function ScopeStrip({ scope, onTap }) {
  const c = UNIT_COLOR[scope];
  const unit = scope === 'objekt' ? null : UNITS.find(u => u.id === scope);
  return (
    <button onClick={onTap} style={{
      width: '100%', height: 32,
      background: c.soft,
      borderTop: `0.5px solid ${TOKENS.separator}`,
      borderBottom: `0.5px solid ${TOKENS.separator}`,
      border: 'none', borderTopWidth: '0.5px', borderBottomWidth: '0.5px',
      borderTopStyle: 'solid', borderBottomStyle: 'solid',
      borderTopColor: TOKENS.separator, borderBottomColor: TOKENS.separator,
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      padding: '0 16px',
      fontFamily: TOKENS.fontSans, fontSize: 12, fontWeight: 500,
      letterSpacing: 0.2, color: c.fg,
      cursor: 'pointer', position: 'relative',
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, minWidth: 0, flex: 1 }}>
        <div style={{
          width: 8, height: 8, borderRadius: 2, background: c.fg, flexShrink: 0,
        }} />
        <span style={{ textTransform: 'uppercase', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
          {scope === 'objekt' 
            ? `Objekt · Gesamtes Haus` 
            : `Einheit · ${unit.label}`}
        </span>
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6, opacity: 0.7, flexShrink: 0 }}>
        <span style={{ fontFamily: TOKENS.fontMono, fontSize: 11, whiteSpace: 'nowrap' }}>
          {scope === 'objekt' ? `${OBJEKT.totalSqm} m²` : `${unit.sqm} m²`}
        </span>
        <Icon name="swap" size={13} color={c.fg} stroke={1.8} />
      </div>
    </button>
  );
}

// ─── Tab bar ────────────────────────────────────────────────
const TABS = [
  { id: 'dashboard', label: 'Übersicht', icon: 'home' },
  { id: 'meters', label: 'Zähler', icon: 'gauge' },
  { id: 'bills', label: 'Rechnung.', icon: 'receipt' },
  { id: 'docs', label: 'Belege', icon: 'doc' },
  { id: 'abrechnungen', label: 'Abrechn.', icon: 'calc' },
  { id: 'settings', label: 'Einstell.', icon: 'settings' },
];

function AppTabBar({ activeTab, onTab, onQuestion }) {
  return (
    <div style={{
      position: 'absolute', bottom: 0, left: 0, right: 0,
      paddingBottom: 22, paddingTop: 6,
      background: 'rgba(245, 241, 232, 0.92)',
      backdropFilter: 'blur(18px) saturate(180%)',
      WebkitBackdropFilter: 'blur(18px) saturate(180%)',
      borderTop: `0.5px solid ${TOKENS.separator}`,
      zIndex: 40,
    }}>
      <div style={{
        display: 'flex', alignItems: 'stretch', justifyContent: 'space-between',
        padding: '0 2px',
      }}>
        {TABS.map(t => {
          const active = activeTab === t.id;
          return (
            <button key={t.id} onClick={() => onTab(t.id)} style={{
              flex: 1, background: 'transparent', border: 'none',
              display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3,
              padding: '4px 1px', cursor: 'pointer', minWidth: 0,
              color: active ? TOKENS.accent : TOKENS.textTertiary,
            }}>
              <Icon name={t.icon} size={20} color={active ? TOKENS.accent : TOKENS.textTertiary} stroke={active ? 2 : 1.6} />
              <span style={{
                fontFamily: TOKENS.fontSans, fontSize: 9.5, fontWeight: active ? 600 : 500,
                letterSpacing: 0, whiteSpace: 'nowrap',
              }}>{t.label}</span>
            </button>
          );
        })}
        <button onClick={onQuestion} style={{
          width: 44, background: 'transparent', border: 'none',
          display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2,
          padding: '4px 2px', cursor: 'pointer',
          color: TOKENS.textTertiary,
        }}>
          <Icon name="question" size={20} color={TOKENS.textTertiary} stroke={1.6} />
          <span style={{
            fontFamily: TOKENS.fontSans, fontSize: 9.5, fontWeight: 500, whiteSpace: 'nowrap',
          }}>Prüfen</span>
        </button>
      </div>
    </div>
  );
}

// ─── Reusable: Card ─────────────────────────────────────────
function Card({ children, style, padding = 14 }) {
  return (
    <div style={{
      background: TOKENS.bgSurface,
      borderRadius: 14,
      border: `0.5px solid ${TOKENS.separator}`,
      padding,
      ...style,
    }}>{children}</div>
  );
}

// ─── Section header ─────────────────────────────────────────
function SectionHeader({ children, action, style }) {
  return (
    <div style={{
      display: 'flex', justifyContent: 'space-between', alignItems: 'baseline',
      padding: '0 4px',
      fontFamily: TOKENS.fontSans, fontSize: 12, fontWeight: 600,
      color: TOKENS.textTertiary, textTransform: 'uppercase', letterSpacing: 0.6,
      whiteSpace: 'nowrap',
      ...style,
    }}>
      <span>{children}</span>
      {action}
    </div>
  );
}

// ─── Status dot / pill ──────────────────────────────────────
function StatusDot({ status, size = 10 }) {
  const colors = {
    ok: TOKENS.statusOk, warn: TOKENS.statusWarn,
    error: TOKENS.statusError, missing: TOKENS.statusError,
    muted: TOKENS.statusMuted, neutral: TOKENS.textTertiary,
  };
  return (
    <div style={{
      width: size, height: size, borderRadius: size / 2,
      background: colors[status] || TOKENS.textTertiary,
      flexShrink: 0,
    }} />
  );
}

function StatusPill({ status, label, mono }) {
  const map = {
    ok: [TOKENS.statusOk, TOKENS.statusOkSoft],
    warn: [TOKENS.statusWarn, TOKENS.statusWarnSoft],
    error: [TOKENS.statusError, TOKENS.statusErrorSoft],
    muted: [TOKENS.statusMuted, TOKENS.statusMutedSoft],
    raw: [TOKENS.textTertiary, 'rgba(138,133,120,0.12)'],
    validated: [TOKENS.statusOk, TOKENS.statusOkSoft],
    suggested: [TOKENS.statusWarn, TOKENS.statusWarnSoft],
    no: [TOKENS.textTertiary, 'rgba(138,133,120,0.12)'],
  };
  const [fg, bg] = map[status] || [TOKENS.textTertiary, 'rgba(138,133,120,0.12)'];
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 5,
      padding: '2px 8px', borderRadius: 10,
      background: bg, color: fg,
      fontFamily: mono ? TOKENS.fontMono : TOKENS.fontSans,
      fontSize: 11, fontWeight: 600, letterSpacing: 0.1,
      whiteSpace: 'nowrap', flexShrink: 0,
    }}>
      <div style={{ width: 5, height: 5, borderRadius: 3, background: fg }} />
      {label}
    </span>
  );
}

// ─── Sheet container (modal bottom sheet) ───────────────────
function Sheet({ open, onClose, title, children, height = '85%' }) {
  if (!open) return null;
  return (
    <div style={{
      position: 'absolute', inset: 0, zIndex: 100,
      display: 'flex', flexDirection: 'column', justifyContent: 'flex-end',
    }}>
      <div onClick={onClose} style={{
        position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.35)',
        animation: 'fadein 0.2s',
      }} />
      <div style={{
        position: 'relative', height,
        background: TOKENS.bgSheet,
        borderTopLeftRadius: 22, borderTopRightRadius: 22,
        boxShadow: '0 -2px 20px rgba(0,0,0,0.08)',
        display: 'flex', flexDirection: 'column',
        animation: 'slideup 0.28s cubic-bezier(0.2,0.9,0.3,1)',
      }}>
        <div style={{
          display: 'flex', justifyContent: 'center', padding: '8px 0 4px',
        }}>
          <div style={{
            width: 36, height: 5, borderRadius: 3, background: 'rgba(60,50,40,0.2)',
          }} />
        </div>
        {title && (
          <div style={{
            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            padding: '8px 16px 12px',
            borderBottom: `0.5px solid ${TOKENS.separator}`,
          }}>
            <div style={{
              fontFamily: TOKENS.fontSans, fontSize: 17, fontWeight: 600,
              color: TOKENS.text,
            }}>{title}</div>
            <button onClick={onClose} style={{
              width: 30, height: 30, borderRadius: 15,
              background: 'rgba(60,50,40,0.08)', border: 'none',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              cursor: 'pointer',
            }}>
              <Icon name="x" size={15} color={TOKENS.textSecondary} stroke={2} />
            </button>
          </div>
        )}
        <div style={{ flex: 1, overflow: 'auto' }}>{children}</div>
      </div>
    </div>
  );
}

// ─── Scope picker menu ──────────────────────────────────────
function ScopePickerSheet({ open, onClose, scope, setScope }) {
  const opts = [
    { id: 'objekt', title: 'Gesamtes Haus', subtitle: `${OBJEKT.address} · ${OBJEKT.totalSqm} m²`, persons: null },
    ...UNITS.map(u => ({ 
      id: u.id, title: u.label, 
      subtitle: `${u.tenantShort} · ${u.sqm} m²`,
      persons: u.persons,
    })),
  ];
  return (
    <Sheet open={open} onClose={onClose} title="Scope wählen" height="60%">
      <div style={{ padding: '8px 16px 20px' }}>
        <div style={{
          fontFamily: TOKENS.fontSans, fontSize: 12, color: TOKENS.textTertiary,
          padding: '8px 4px 10px', letterSpacing: 0.2,
        }}>
          Wähle, welcher Ausschnitt der Abrechnung im Vordergrund stehen soll.
        </div>
        {opts.map((o, i) => {
          const c = UNIT_COLOR[o.id];
          const active = scope === o.id;
          return (
            <button key={o.id} onClick={() => { setScope(o.id); onClose(); }} style={{
              display: 'flex', alignItems: 'center', gap: 12,
              width: '100%', padding: '14px 12px',
              background: active ? c.soft : TOKENS.bgSurface,
              border: `1px solid ${active ? c.fg : TOKENS.separator}`,
              borderRadius: 12, marginBottom: 8,
              cursor: 'pointer', textAlign: 'left',
            }}>
              <div style={{
                width: 6, alignSelf: 'stretch', borderRadius: 3,
                background: c.fg,
              }} />
              <div style={{ flex: 1 }}>
                <div style={{
                  fontFamily: TOKENS.fontSans, fontSize: 16, fontWeight: 600,
                  color: TOKENS.text, marginBottom: 2,
                }}>{o.title}</div>
                <div style={{
                  fontFamily: TOKENS.fontSans, fontSize: 13, color: TOKENS.textSecondary,
                }}>{o.subtitle}</div>
              </div>
              {active && <Icon name="check" size={20} color={c.fg} stroke={2.2} />}
            </button>
          );
        })}
      </div>
    </Sheet>
  );
}

Object.assign(window, {
  AppNavBar, ScopeStrip, AppTabBar, TABS, Card, SectionHeader,
  StatusDot, StatusPill, Sheet, ScopePickerSheet,
});
