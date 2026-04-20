// Abrechnung detail + Settings + Scan + Completeness inspector + PDF preview

function AbrechnungenScreen({ scope, setActiveUnit, onOpenUnit }) {
  if (scope !== 'objekt') {
    return <AbrechnungDetail unitId={scope} />;
  }
  return (
    <div style={{ padding: '14px 16px 130px', display: 'flex', flexDirection: 'column', gap: 16 }}>
      <div style={{
        padding: '14px 16px',
        background: TOKENS.bgSurface,
        border: `0.5px solid ${TOKENS.separator}`,
        borderRadius: 14,
      }}>
        <div style={{
          fontFamily: TOKENS.fontSans, fontSize: 12, fontWeight: 600,
          color: TOKENS.textTertiary, letterSpacing: 0.6, textTransform: 'uppercase',
          marginBottom: 6,
        }}>Abrechnungsperiode {OBJEKT.periodShort}</div>
        <div style={{
          fontFamily: TOKENS.fontSans, fontSize: 13, color: TOKENS.textSecondary, lineHeight: 1.5,
        }}>Pro Einheit wird eine eigene Abrechnung erzeugt. Öffnen, prüfen, als PDF exportieren.</div>
      </div>

      <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
        {UNITS.map(u => {
          const c = UNIT_COLOR[u.id];
          const vz = u.vorauszahlung * 12;
          const istFactor = u.id === 'og' ? 1 : (u.sqm / 128) * 0.92;
          const ist = ABRECHNUNG_OG.positions.reduce((s, p) => s + p.unitShare, 0) * istFactor;
          const saldo = vz - ist;
          const status = u.id === 'og' ? 'warn' : (u.id === 'eg' ? 'ok' : 'warn');
          const statusLabel = { ok: 'Fertig', warn: 'In Arbeit', error: 'Fehlt' }[status];
          
          return (
            <button key={u.id} onClick={() => onOpenUnit(u.id)} style={{
              display: 'flex', alignItems: 'stretch', gap: 12,
              padding: 0,
              background: TOKENS.bgSurface,
              border: `0.5px solid ${TOKENS.separator}`,
              borderRadius: 14, cursor: 'pointer', textAlign: 'left',
              overflow: 'hidden',
            }}>
              <div style={{ width: 6, background: c.fg }} />
              <div style={{ flex: 1, padding: '14px 14px 14px 4px' }}>
                <div style={{
                  display: 'flex', justifyContent: 'space-between', alignItems: 'baseline',
                  marginBottom: 6,
                }}>
                  <div>
                    <div style={{
                      fontFamily: TOKENS.fontSans, fontSize: 16, fontWeight: 600, color: TOKENS.text,
                    }}>{u.label}</div>
                    <div style={{
                      fontFamily: TOKENS.fontSans, fontSize: 13, color: TOKENS.textSecondary,
                      marginTop: 1,
                    }}>{u.tenant}</div>
                  </div>
                  <StatusPill status={status} label={statusLabel} />
                </div>
                <div style={{
                  marginTop: 10, paddingTop: 10,
                  borderTop: `0.5px solid ${TOKENS.separator}`,
                  display: 'flex', justifyContent: 'space-between', alignItems: 'baseline',
                }}>
                  <span style={{
                    fontFamily: TOKENS.fontSans, fontSize: 12, color: TOKENS.textSecondary,
                  }}>{saldo >= 0 ? 'Guthaben' : 'Nachzahlung'}</span>
                  <span style={{
                    fontFamily: TOKENS.fontMono, fontSize: 18, fontWeight: 600,
                    color: saldo >= 0 ? TOKENS.statusOk : TOKENS.statusError,
                  }}>{saldo >= 0 ? '+' : '−'} {fmtEuro(Math.abs(saldo))}</span>
                </div>
              </div>
            </button>
          );
        })}
      </div>
    </div>
  );
}

function AbrechnungDetail({ unitId, onPdf }) {
  const unit = UNITS.find(u => u.id === unitId);
  const c = UNIT_COLOR[unitId];
  const og = ABRECHNUNG_OG;
  const factor = unitId === 'og' ? 1 : (unit.sqm / 128) * 0.92;
  const positions = og.positions.filter(p => p.unitShare > 0).map(p => ({
    ...p, unitShare: p.unitShare * factor
  }));
  const total = positions.reduce((s, p) => s + p.unitShare, 0);
  const vz = unit.vorauszahlung * 12;
  const saldo = vz - total;

  return (
    <div style={{ padding: '14px 16px 130px', display: 'flex', flexDirection: 'column', gap: 14 }}>
      {/* Header */}
      <div style={{
        background: TOKENS.bgSurface,
        border: `0.5px solid ${TOKENS.separator}`,
        borderLeft: `4px solid ${c.fg}`,
        borderRadius: 14, padding: '14px 16px',
      }}>
        <div style={{
          fontFamily: TOKENS.fontSans, fontSize: 11, color: TOKENS.textTertiary,
          letterSpacing: 0.5, textTransform: 'uppercase',
        }}>Abrechnung {OBJEKT.periodShort} · {unit.label}</div>
        <div style={{
          fontFamily: TOKENS.fontSans, fontSize: 17, fontWeight: 600, color: TOKENS.text,
          marginTop: 4,
        }}>{unit.tenant}</div>
        <div style={{
          fontFamily: TOKENS.fontSans, fontSize: 13, color: TOKENS.textSecondary,
          marginTop: 2,
        }}>{OBJEKT.address}, {OBJEKT.city} · {OBJEKT.period}</div>
      </div>

      {/* Positions table */}
      <div>
        <SectionHeader style={{ marginBottom: 8 }}>Kostenpositionen</SectionHeader>
        <div style={{
          background: TOKENS.bgSurface,
          border: `0.5px solid ${TOKENS.separator}`,
          borderRadius: 12, overflow: 'hidden',
        }}>
          {positions.map((p, i) => (
            <div key={i} style={{
              padding: '10px 12px',
              borderBottom: i < positions.length - 1 ? `0.5px solid ${TOKENS.separator}` : 'none',
            }}>
              <div style={{ display: 'flex', gap: 10, alignItems: 'baseline' }}>
                <span style={{
                  flex: 1, minWidth: 0,
                  fontFamily: TOKENS.fontSans, fontSize: 13, fontWeight: 500, color: TOKENS.text,
                }}>{p.label}</span>
                <span style={{
                  fontFamily: TOKENS.fontMono, fontSize: 13, fontWeight: 600, color: TOKENS.text,
                  whiteSpace: 'nowrap', flexShrink: 0,
                }}>{fmtEuro(p.unitShare)}</span>
              </div>
              <div style={{
                display: 'flex', gap: 8, marginTop: 3,
                fontFamily: TOKENS.fontMono, fontSize: 10, color: TOKENS.textTertiary,
              }}>
                <span>{p.schluessel}</span>
                {p.base > 0 && <span>· Basis {fmtEuro(p.base)}</span>}
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Totals */}
      <div style={{
        background: TOKENS.bgSurface,
        border: `0.5px solid ${TOKENS.separator}`,
        borderRadius: 12, overflow: 'hidden',
      }}>
        <TotalRow label="Gesamte Nebenkosten" value={fmtEuro(total)} />
        <TotalRow label={`Vorauszahlungen (12 × ${fmtEuro(unit.vorauszahlung)})`} 
          value={'− ' + fmtEuro(vz)} />
        <div style={{
          padding: '14px 14px',
          background: saldo >= 0 ? TOKENS.statusOkSoft : TOKENS.statusErrorSoft,
          display: 'flex', justifyContent: 'space-between', alignItems: 'baseline',
        }}>
          <div>
            <div style={{
              fontFamily: TOKENS.fontSans, fontSize: 11,
              color: saldo >= 0 ? TOKENS.statusOk : TOKENS.statusError,
              letterSpacing: 0.5, textTransform: 'uppercase',
            }}>Ergebnis</div>
            <div style={{
              fontFamily: TOKENS.fontSans, fontSize: 15, fontWeight: 600,
              color: saldo >= 0 ? TOKENS.statusOk : TOKENS.statusError,
              marginTop: 2,
            }}>{saldo >= 0 ? 'Guthaben für Mieter' : 'Nachzahlung durch Mieter'}</div>
          </div>
          <div style={{
            fontFamily: TOKENS.fontMono, fontSize: 24, fontWeight: 600,
            color: saldo >= 0 ? TOKENS.statusOk : TOKENS.statusError,
          }}>{saldo >= 0 ? '+' : '−'} {fmtEuro(Math.abs(saldo))}</div>
        </div>
      </div>

      {/* Legal note */}
      <div style={{
        padding: '10px 12px', background: TOKENS.bgSurfaceAlt,
        borderRadius: 8, border: `0.5px solid ${TOKENS.separator}`,
        fontFamily: TOKENS.fontSans, fontSize: 11, color: TOKENS.textSecondary,
        lineHeight: 1.5,
      }}>
        Heizung nach §7 HeizkostenV (70 % Verbrauch / 30 % Fläche). Kostenpositionen nach BetrKV.
        Einspruchsfrist 12 Monate nach Zugang (§556 Abs. 3 BGB).
      </div>

      {/* Actions */}
      <div style={{ display: 'flex', gap: 8 }}>
        <button onClick={onPdf} style={{
          flex: 1, padding: '14px',
          background: TOKENS.accent, color: 'white',
          border: 'none', borderRadius: 12,
          fontFamily: TOKENS.fontSans, fontSize: 15, fontWeight: 600,
          cursor: 'pointer',
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
        }}>
          <Icon name="download" size={16} color="white" stroke={1.9} />
          PDF erzeugen
        </button>
        <button style={{
          padding: '14px',
          background: TOKENS.bgSurface, color: TOKENS.accent,
          border: `1px solid ${TOKENS.accent}`, borderRadius: 12,
          fontFamily: TOKENS.fontSans, fontSize: 15, fontWeight: 600,
          cursor: 'pointer',
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
          width: 54,
        }}>
          <Icon name="mail" size={16} color={TOKENS.accent} stroke={1.9} />
        </button>
      </div>
    </div>
  );
}

function TotalRow({ label, value }) {
  return (
    <div style={{
      padding: '12px 14px',
      borderBottom: `0.5px solid ${TOKENS.separator}`,
      display: 'flex', justifyContent: 'space-between', alignItems: 'baseline',
    }}>
      <span style={{
        fontFamily: TOKENS.fontSans, fontSize: 13, color: TOKENS.textSecondary,
      }}>{label}</span>
      <span style={{
        fontFamily: TOKENS.fontMono, fontSize: 14, fontWeight: 600, color: TOKENS.text,
      }}>{value}</span>
    </div>
  );
}

// ─── Settings ──────────────────────────────────────────────
function SettingsScreen({ scope }) {
  return (
    <div style={{ padding: '14px 16px 130px', display: 'flex', flexDirection: 'column', gap: 16 }}>
      <SettingsGroup header="Objekt">
        <SettingsRow label="Adresse" value={`${OBJEKT.address}, ${OBJEKT.city}`} />
        <SettingsRow label="Abrechnungsperiode" value={OBJEKT.period} mono />
        <SettingsRow label="Gesamtwohnfläche" value={`${OBJEKT.totalSqm} m²`} mono />
        <SettingsRow label="Einheiten" value={`${UNITS.length} (${UNITS.map(u=>u.short).join(' · ')})`} last />
      </SettingsGroup>

      <SettingsGroup header="Mieter & Vorauszahlungen">
        {UNITS.map((u, i) => (
          <SettingsRow key={u.id} 
            label={u.label} 
            value={`${fmtEuro(u.vorauszahlung)} / Monat`} 
            sub={u.tenantShort}
            unitColor={UNIT_COLOR[u.id].fg}
            last={i === UNITS.length - 1} />
        ))}
      </SettingsGroup>

      <SettingsGroup header="Umlageschlüssel (BetrKV)">
        <SettingsRow label="Heizung & Warmwasser" value="§7/§8 HeizkostenV" />
        <SettingsRow label="Kaltwasser" value="Verbrauch (m³)" />
        <SettingsRow label="Müllabfuhr" value="Personen" />
        <SettingsRow label="Grundsteuer & Versicherung" value="Wohnfläche" />
        <SettingsRow label="Hauswart & Reinigung" value="Wohnfläche" last />
      </SettingsGroup>

      <SettingsGroup header="App">
        <SettingsRow label="Konfidenz-Schwelle KI" value="60 %" mono />
        <SettingsRow label="Darstellung" value="Hell" />
        <SettingsRow label="Daten exportieren" value="" icon />
        <SettingsRow label="Rechtshinweise" value="" icon last />
      </SettingsGroup>
    </div>
  );
}

function SettingsGroup({ header, children }) {
  return (
    <div>
      <div style={{
        padding: '0 4px 8px',
        fontFamily: TOKENS.fontSans, fontSize: 12, fontWeight: 600,
        color: TOKENS.textTertiary, letterSpacing: 0.6, textTransform: 'uppercase',
      }}>{header}</div>
      <div style={{
        background: TOKENS.bgSurface,
        border: `0.5px solid ${TOKENS.separator}`,
        borderRadius: 14, overflow: 'hidden',
      }}>{children}</div>
    </div>
  );
}

function SettingsRow({ label, value, sub, last, mono, icon, unitColor }) {
  return (
    <div style={{
      padding: '12px 14px',
      borderBottom: last ? 'none' : `0.5px solid ${TOKENS.separator}`,
      display: 'flex', alignItems: 'center', gap: 10,
    }}>
      {unitColor && (
        <div style={{ width: 4, height: 24, borderRadius: 2, background: unitColor }} />
      )}
      <div style={{ flex: 1 }}>
        <div style={{
          fontFamily: TOKENS.fontSans, fontSize: 14, fontWeight: 500, color: TOKENS.text,
        }}>{label}</div>
        {sub && <div style={{
          fontFamily: TOKENS.fontSans, fontSize: 12, color: TOKENS.textSecondary, marginTop: 1,
        }}>{sub}</div>}
      </div>
      {value && <div style={{
        fontFamily: mono ? TOKENS.fontMono : TOKENS.fontSans, fontSize: 13,
        color: TOKENS.textSecondary,
      }}>{value}</div>}
      {icon && <Icon name="chevronRight" size={14} color={TOKENS.textQuaternary} stroke={2} />}
    </div>
  );
}

Object.assign(window, { AbrechnungenScreen, AbrechnungDetail, SettingsScreen });
