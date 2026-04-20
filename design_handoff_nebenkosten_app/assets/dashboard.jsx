// Dashboard screens — Objekt-Scope & Einheit-Scope

function Dashboard({ scope, setActiveTab, openInspector }) {
  if (scope === 'objekt') return <DashboardObjekt setActiveTab={setActiveTab} openInspector={openInspector} />;
  return <DashboardEinheit unitId={scope} setActiveTab={setActiveTab} />;
}

// ─── Objekt scope ───────────────────────────────────────────
function DashboardObjekt({ setActiveTab, openInspector }) {
  const totalCosts = BILLS.filter(b => b.umlage === 'ok').reduce((s, b) => s + b.amount, 0);
  const validated = BILLS.filter(b => b.umlage === 'ok' && b.confidence === 'validated').reduce((s, b) => s + b.amount, 0);
  const open = COMPLETENESS.filter(c => c.status !== 'ok');
  const totalVorauszahlung = UNITS.reduce((s, u) => s + u.vorauszahlung * 12, 0);

  return (
    <div style={{ padding: '16px 16px 130px', display: 'flex', flexDirection: 'column', gap: 20 }}>
      {/* Period card */}
      <div style={{
        background: TOKENS.bgSurface,
        border: `0.5px solid ${TOKENS.separator}`,
        borderRadius: 14, padding: '14px 16px',
      }}>
        <div style={{
          display: 'flex', justifyContent: 'space-between', alignItems: 'baseline',
          marginBottom: 10, gap: 8,
        }}>
          <div style={{
            fontFamily: TOKENS.fontSans, fontSize: 12, fontWeight: 600,
            color: TOKENS.textTertiary, letterSpacing: 0.6, textTransform: 'uppercase',
            whiteSpace: 'nowrap',
          }}>Abrechnungsperiode</div>
          <div style={{
            fontFamily: TOKENS.fontMono, fontSize: 11, color: TOKENS.textSecondary,
            whiteSpace: 'nowrap', flexShrink: 0,
          }}>{OBJEKT.periodShort || '2025'}</div>
        </div>
        <div style={{ display: 'flex', gap: 0 }}>
          <StatBlock label="Umlagefähige Kosten" value={fmtEuro(totalCosts)} mono 
            sub={`${BILLS.filter(b=>b.umlage==='ok').length} Rechnungen`} />
          <div style={{ width: 0.5, alignSelf: 'stretch', background: TOKENS.separator, margin: '0 14px' }} />
          <StatBlock label="Vorauszahlungen" value={fmtEuro(totalVorauszahlung)} mono
            sub={`${UNITS.length} Einheiten`} />
        </div>
        <div style={{
          marginTop: 14, paddingTop: 12, borderTop: `0.5px solid ${TOKENS.separator}`,
          display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8,
        }}>
          <div style={{ minWidth: 0, flex: 1 }}>
            <div style={{
              fontFamily: TOKENS.fontSans, fontSize: 13, color: TOKENS.textSecondary,
              marginBottom: 2, whiteSpace: 'nowrap',
            }}>Validiert & bereit</div>
            <div style={{
              fontFamily: TOKENS.fontMono, fontSize: 12, color: TOKENS.statusOk, fontWeight: 600,
              whiteSpace: 'nowrap',
            }}>{fmtEuro(validated)} ∕ {fmtEuro(totalCosts)}</div>
          </div>
          <div style={{
            fontFamily: TOKENS.fontMono, fontSize: 22, color: TOKENS.text, fontWeight: 600,
            flexShrink: 0,
          }}>{Math.round(validated / totalCosts * 100)}%</div>
        </div>
        {/* Progress rail */}
        <div style={{
          marginTop: 10, height: 4, borderRadius: 2, background: TOKENS.separator, overflow: 'hidden',
        }}>
          <div style={{
            height: '100%', width: `${validated / totalCosts * 100}%`,
            background: TOKENS.statusOk,
          }} />
        </div>
      </div>

      {/* Vollständigkeit */}
      <div>
        <SectionHeader style={{ marginBottom: 10 }}>
          Offene Punkte
          <button onClick={openInspector} style={{
            background: 'transparent', border: 'none',
            fontFamily: TOKENS.fontSans, fontSize: 12, fontWeight: 500,
            color: TOKENS.accent, cursor: 'pointer', textTransform: 'none', letterSpacing: 0,
          }}>Alle {COMPLETENESS.length} prüfen →</button>
        </SectionHeader>
        <div style={{
          background: TOKENS.bgSurface,
          border: `0.5px solid ${TOKENS.separator}`,
          borderRadius: 14, overflow: 'hidden',
        }}>
          {open.map((c, i) => (
            <button key={c.id} onClick={() => c.link && setActiveTab(c.link.tab)} style={{
              display: 'flex', alignItems: 'flex-start', gap: 12, width: '100%',
              padding: '13px 14px',
              borderBottom: i < open.length - 1 ? `0.5px solid ${TOKENS.separator}` : 'none',
              background: 'transparent', border: 'none', borderBottom: i < open.length - 1 ? `0.5px solid ${TOKENS.separator}` : 'none',
              cursor: 'pointer', textAlign: 'left',
            }}>
              <div style={{ marginTop: 4 }}>
                <StatusDot status={c.status} size={8} />
              </div>
              <div style={{ flex: 1 }}>
                <div style={{
                  fontFamily: TOKENS.fontSans, fontSize: 15, fontWeight: 500,
                  color: TOKENS.text, marginBottom: 2,
                }}>{c.label}</div>
                <div style={{
                  fontFamily: TOKENS.fontSans, fontSize: 12, color: TOKENS.textSecondary,
                }}>{c.detail}</div>
              </div>
              <Icon name="chevronRight" size={14} color={TOKENS.textQuaternary} stroke={2} />
            </button>
          ))}
          {open.length === 0 && (
            <div style={{
              padding: '20px 14px', textAlign: 'center',
              fontFamily: TOKENS.fontSans, fontSize: 14, color: TOKENS.textSecondary,
            }}>Alle Prüfpunkte bestanden.</div>
          )}
        </div>
      </div>

      {/* Einheiten-Übersicht */}
      <div>
        <SectionHeader style={{ marginBottom: 10 }}>Einheiten</SectionHeader>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {UNITS.map(u => {
            const c = UNIT_COLOR[u.id];
            return (
              <div key={u.id} style={{
                background: TOKENS.bgSurface,
                border: `0.5px solid ${TOKENS.separator}`,
                borderRadius: 12, padding: '12px 14px',
                display: 'flex', alignItems: 'center', gap: 12,
              }}>
                <div style={{
                  width: 4, alignSelf: 'stretch', borderRadius: 2,
                  background: c.fg, flexShrink: 0,
                }} />
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{
                    display: 'flex', alignItems: 'baseline', gap: 8, marginBottom: 2,
                  }}>
                    <span style={{
                      fontFamily: TOKENS.fontSans, fontSize: 15, fontWeight: 600,
                      color: TOKENS.text, whiteSpace: 'nowrap',
                    }}>{u.label}</span>
                    <span style={{
                      fontFamily: TOKENS.fontMono, fontSize: 11, color: TOKENS.textTertiary,
                      whiteSpace: 'nowrap', flexShrink: 0,
                    }}>{u.sqm} m²</span>
                  </div>
                  <div style={{
                    fontFamily: TOKENS.fontSans, fontSize: 13, color: TOKENS.textSecondary,
                    whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis',
                  }}>{u.tenantShort || u.tenant}</div>
                </div>
                <div style={{ textAlign: 'right', flexShrink: 0 }}>
                  <div style={{
                    fontFamily: TOKENS.fontMono, fontSize: 14, fontWeight: 600, color: TOKENS.text,
                    whiteSpace: 'nowrap',
                  }}>{fmtEuro(u.vorauszahlung)}</div>
                  <div style={{
                    fontFamily: TOKENS.fontSans, fontSize: 10, color: TOKENS.textTertiary,
                    letterSpacing: 0.2, whiteSpace: 'nowrap',
                  }}>Vorauszahlung / Monat</div>
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Quick actions */}
      <div>
        <SectionHeader style={{ marginBottom: 10 }}>Schnellaktionen</SectionHeader>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
          <QuickAction icon="camera" label="Beleg scannen" onClick={() => {}} primary />
          <QuickAction icon="gauge" label="Zählerstand erfassen" onClick={() => setActiveTab('meters')} />
          <QuickAction icon="plus" label="Rechnung manuell" onClick={() => setActiveTab('bills')} />
          <QuickAction icon="calc" label="Abrechnung rechnen" onClick={() => setActiveTab('abrechnungen')} />
        </div>
      </div>
    </div>
  );
}

function StatBlock({ label, value, sub, mono }) {
  return (
    <div style={{ flex: 1, minWidth: 0 }}>
      <div style={{
        fontFamily: TOKENS.fontSans, fontSize: 11, color: TOKENS.textTertiary,
        letterSpacing: 0.2, marginBottom: 4, whiteSpace: 'nowrap',
        overflow: 'hidden', textOverflow: 'ellipsis',
      }}>{label}</div>
      <div style={{
        fontFamily: mono ? TOKENS.fontMono : TOKENS.fontSans, fontSize: 19, fontWeight: 600,
        color: TOKENS.text, letterSpacing: -0.3, whiteSpace: 'nowrap',
      }}>{value}</div>
      {sub && <div style={{
        fontFamily: TOKENS.fontSans, fontSize: 11, color: TOKENS.textTertiary, marginTop: 2,
        whiteSpace: 'nowrap',
      }}>{sub}</div>}
    </div>
  );
}

function QuickAction({ icon, label, onClick, primary }) {
  return (
    <button onClick={onClick} style={{
      display: 'flex', flexDirection: 'column', alignItems: 'flex-start', gap: 8,
      padding: '14px 14px',
      background: primary ? TOKENS.accent : TOKENS.bgSurface,
      color: primary ? TOKENS.accentText : TOKENS.text,
      border: primary ? 'none' : `0.5px solid ${TOKENS.separator}`,
      borderRadius: 12, cursor: 'pointer', textAlign: 'left',
    }}>
      <Icon name={icon} size={22} color={primary ? TOKENS.accentText : TOKENS.accent} stroke={1.8} />
      <span style={{
        fontFamily: TOKENS.fontSans, fontSize: 13, fontWeight: 500,
      }}>{label}</span>
    </button>
  );
}

// ─── Einheit scope ──────────────────────────────────────────
function DashboardEinheit({ unitId, setActiveTab }) {
  const unit = UNITS.find(u => u.id === unitId);
  const c = UNIT_COLOR[unitId];
  const vorauszahlungJahr = unit.vorauszahlung * 12;
  
  // Use OG Pfaffenbach's computed sums for demo; for others, approximate proportionally
  const og = ABRECHNUNG_OG;
  const totalOG = og.positions.reduce((s, p) => s + p.unitShare, 0);
  const factor = unit.sqm / 128; // rough for non-OG
  const istKosten = unitId === 'og' ? totalOG : totalOG * factor * 0.92;
  const saldo = vorauszahlungJahr - istKosten;
  const isGuthaben = saldo >= 0;

  // missing docs for this unit
  const missing = [];
  if (unitId === 'og') {
    missing.push({ label: 'Warmwasser-Endstand OG', tab: 'meters' });
    missing.push({ label: 'Kaltwasser-Endstand OG', tab: 'meters' });
  }

  return (
    <div style={{ padding: '16px 16px 130px', display: 'flex', flexDirection: 'column', gap: 20 }}>
      {/* Tenant card */}
      <div style={{
        background: TOKENS.bgSurface,
        border: `0.5px solid ${TOKENS.separator}`,
        borderRadius: 14, padding: '14px 16px',
        borderLeft: `4px solid ${c.fg}`,
      }}>
        <div style={{
          fontFamily: TOKENS.fontSans, fontSize: 12, color: TOKENS.textTertiary,
          textTransform: 'uppercase', letterSpacing: 0.6, marginBottom: 4,
        }}>{unit.longLabel}</div>
        <div style={{
          fontFamily: TOKENS.fontSans, fontSize: 20, fontWeight: 600,
          color: TOKENS.text, marginBottom: 2,
        }}>{unit.tenant}</div>
        <div style={{
          fontFamily: TOKENS.fontSans, fontSize: 13, color: TOKENS.textSecondary,
        }}>Seit {unit.moveIn} · {unit.sqm} m² · {unit.persons} Personen</div>
      </div>

      {/* Saldo preview */}
      <div style={{
        background: TOKENS.bgSurface,
        border: `0.5px solid ${TOKENS.separator}`,
        borderRadius: 14, padding: '16px',
      }}>
        <div style={{
          display: 'flex', justifyContent: 'space-between', alignItems: 'baseline',
          marginBottom: 12,
        }}>
          <div style={{
            fontFamily: TOKENS.fontSans, fontSize: 12, fontWeight: 600,
            color: TOKENS.textTertiary, letterSpacing: 0.6, textTransform: 'uppercase',
          }}>Abrechnung {OBJEKT.periodShort}</div>
          <StatusPill status={missing.length > 0 ? 'warn' : 'ok'} 
            label={missing.length > 0 ? 'In Arbeit' : 'Bereit'} />
        </div>
        
        <div style={{
          display: 'flex', flexDirection: 'column', gap: 10,
          fontFamily: TOKENS.fontMono, fontSize: 14,
        }}>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <span style={{ color: TOKENS.textSecondary, fontFamily: TOKENS.fontSans, fontSize: 14 }}>
              Vorauszahlungen (12 Monate)
            </span>
            <span>{fmtEuro(vorauszahlungJahr)}</span>
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <span style={{ color: TOKENS.textSecondary, fontFamily: TOKENS.fontSans, fontSize: 14 }}>
              Ist-Kosten (vorläufig)
            </span>
            <span>− {fmtEuro(istKosten)}</span>
          </div>
          <div style={{
            display: 'flex', justifyContent: 'space-between', alignItems: 'baseline',
            paddingTop: 10, borderTop: `0.5px solid ${TOKENS.separator}`,
          }}>
            <span style={{
              fontFamily: TOKENS.fontSans, fontSize: 13, fontWeight: 600,
              color: TOKENS.text,
            }}>{isGuthaben ? 'Guthaben für Mieter' : 'Nachzahlung Mieter'}</span>
            <span style={{
              fontFamily: TOKENS.fontMono, fontSize: 22, fontWeight: 600,
              color: isGuthaben ? TOKENS.statusOk : TOKENS.statusError,
            }}>{isGuthaben ? '+' : '−'} {fmtEuro(Math.abs(saldo), { decimals: 2 })}</span>
          </div>
        </div>

        {missing.length > 0 && (
          <div style={{
            marginTop: 12, padding: '10px 12px',
            background: TOKENS.statusWarnSoft, borderRadius: 8,
            display: 'flex', gap: 8,
          }}>
            <Icon name="warn" size={16} color={TOKENS.statusWarn} stroke={1.8} />
            <div style={{
              flex: 1,
              fontFamily: TOKENS.fontSans, fontSize: 12, color: TOKENS.statusWarn,
              lineHeight: 1.4,
            }}>
              Vorläufig, weil noch {missing.length} Messwerte fehlen. Werte sind noch nicht final.
            </div>
          </div>
        )}
      </div>

      {/* Missing for this unit */}
      {missing.length > 0 && (
        <div>
          <SectionHeader style={{ marginBottom: 10 }}>Fehlt für diese Einheit</SectionHeader>
          <div style={{
            background: TOKENS.bgSurface,
            border: `0.5px solid ${TOKENS.separator}`,
            borderRadius: 14, overflow: 'hidden',
          }}>
            {missing.map((m, i) => (
              <button key={i} onClick={() => setActiveTab(m.tab)} style={{
                display: 'flex', alignItems: 'center', gap: 10, width: '100%',
                padding: '13px 14px',
                borderBottom: i < missing.length - 1 ? `0.5px solid ${TOKENS.separator}` : 'none',
                background: 'transparent',
                cursor: 'pointer', textAlign: 'left',
              }}>
                <StatusDot status="error" size={8} />
                <span style={{ flex: 1,
                  fontFamily: TOKENS.fontSans, fontSize: 15, color: TOKENS.text,
                }}>{m.label}</span>
                <Icon name="chevronRight" size={14} color={TOKENS.textQuaternary} stroke={2} />
              </button>
            ))}
          </div>
        </div>
      )}

      {/* Unit key facts */}
      <div>
        <SectionHeader style={{ marginBottom: 10 }}>Vertragsdaten</SectionHeader>
        <div style={{
          background: TOKENS.bgSurface,
          border: `0.5px solid ${TOKENS.separator}`,
          borderRadius: 14,
        }}>
          <DataRow label="Mieter" value={unit.tenant} />
          <DataRow label="Einzug" value={unit.moveIn} mono />
          <DataRow label="Wohnfläche" value={`${unit.sqm} m²`} mono />
          <DataRow label="Personen" value={String(unit.persons)} mono />
          <DataRow label="Vorauszahlung / Monat" value={fmtEuro(unit.vorauszahlung)} mono last />
        </div>
      </div>

      <button onClick={() => setActiveTab('abrechnungen')} style={{
        padding: '14px',
        background: c.fg, color: 'white',
        border: 'none', borderRadius: 12,
        fontFamily: TOKENS.fontSans, fontSize: 16, fontWeight: 600,
        cursor: 'pointer',
        display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
      }}>
        <Icon name="calc" size={18} color="white" stroke={1.9} />
        Abrechnung öffnen
      </button>
    </div>
  );
}

function DataRow({ label, value, mono, last }) {
  return (
    <div style={{
      display: 'flex', justifyContent: 'space-between', alignItems: 'center',
      padding: '12px 14px',
      borderBottom: last ? 'none' : `0.5px solid ${TOKENS.separator}`,
    }}>
      <span style={{
        fontFamily: TOKENS.fontSans, fontSize: 14, color: TOKENS.textSecondary,
      }}>{label}</span>
      <span style={{
        fontFamily: mono ? TOKENS.fontMono : TOKENS.fontSans, fontSize: 14, fontWeight: 500,
        color: TOKENS.text,
      }}>{value}</span>
    </div>
  );
}

Object.assign(window, { Dashboard, DashboardObjekt, DashboardEinheit, StatBlock, QuickAction, DataRow });
