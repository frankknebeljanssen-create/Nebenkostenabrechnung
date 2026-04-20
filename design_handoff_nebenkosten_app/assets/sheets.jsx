// Completeness inspector, Scan flow, PDF preview sheets

function CompletenessSheet({ open, onClose, setActiveTab }) {
  const byGroup = {};
  COMPLETENESS.forEach(c => {
    if (!byGroup[c.group]) byGroup[c.group] = [];
    byGroup[c.group].push(c);
  });
  const ok = COMPLETENESS.filter(c => c.status === 'ok').length;
  const total = COMPLETENESS.length;

  return (
    <Sheet open={open} onClose={onClose} title="Vollständigkeits-Inspektor" height="85%">
      <div style={{ padding: '8px 16px 30px' }}>
        <div style={{
          padding: '14px 16px', marginBottom: 16,
          background: TOKENS.bgSurface,
          border: `0.5px solid ${TOKENS.separator}`,
          borderRadius: 12,
        }}>
          <div style={{
            fontFamily: TOKENS.fontSans, fontSize: 13, color: TOKENS.textSecondary,
            marginBottom: 4,
          }}>Status Abrechnung {OBJEKT.periodShort}</div>
          <div style={{
            display: 'flex', justifyContent: 'space-between', alignItems: 'baseline',
          }}>
            <span style={{
              fontFamily: TOKENS.fontSans, fontSize: 20, fontWeight: 600, color: TOKENS.text,
            }}>{ok === total ? 'Bereit zum Rechnen' : 'Noch nicht bereit'}</span>
            <span style={{
              fontFamily: TOKENS.fontMono, fontSize: 16, fontWeight: 600,
              color: ok === total ? TOKENS.statusOk : TOKENS.statusWarn,
            }}>{ok} / {total}</span>
          </div>
          <div style={{
            marginTop: 10, height: 4, borderRadius: 2,
            background: TOKENS.separator, overflow: 'hidden',
          }}>
            <div style={{
              height: '100%', width: `${ok/total*100}%`,
              background: ok === total ? TOKENS.statusOk : TOKENS.statusWarn,
            }} />
          </div>
        </div>

        {Object.entries(byGroup).map(([group, items]) => (
          <div key={group} style={{ marginBottom: 16 }}>
            <div style={{
              padding: '0 4px 8px',
              fontFamily: TOKENS.fontSans, fontSize: 12, fontWeight: 600,
              color: TOKENS.textTertiary, letterSpacing: 0.6, textTransform: 'uppercase',
            }}>{group}</div>
            <div style={{
              background: TOKENS.bgSurface,
              border: `0.5px solid ${TOKENS.separator}`,
              borderRadius: 12, overflow: 'hidden',
            }}>
              {items.map((c, i) => (
                <button key={c.id} onClick={() => {
                  if (c.link) { setActiveTab(c.link.tab); onClose(); }
                }} style={{
                  display: 'flex', alignItems: 'flex-start', gap: 10, width: '100%',
                  padding: '12px 14px',
                  borderBottom: i < items.length - 1 ? `0.5px solid ${TOKENS.separator}` : 'none',
                  background: 'transparent', border: 'none', 
                  borderBottom: i < items.length - 1 ? `0.5px solid ${TOKENS.separator}` : 'none',
                  cursor: c.link ? 'pointer' : 'default', textAlign: 'left',
                }}>
                  <div style={{ marginTop: 4 }}>
                    <StatusDot status={c.status} size={8} />
                  </div>
                  <div style={{ flex: 1 }}>
                    <div style={{
                      fontFamily: TOKENS.fontSans, fontSize: 14, fontWeight: 500, color: TOKENS.text,
                    }}>{c.label}</div>
                    <div style={{
                      fontFamily: TOKENS.fontSans, fontSize: 12, color: TOKENS.textSecondary,
                      marginTop: 2,
                    }}>{c.detail}</div>
                  </div>
                  {c.link && <Icon name="chevronRight" size={14} color={TOKENS.textQuaternary} stroke={2} />}
                </button>
              ))}
            </div>
          </div>
        ))}
      </div>
    </Sheet>
  );
}

// ─── Scan flow ──────────────────────────────────────────────
function ScanSheet({ open, onClose }) {
  const [step, setStep] = useState(0); // 0: camera, 1: processing, 2: fields

  useEffect(() => {
    if (open) setStep(0);
  }, [open]);

  useEffect(() => {
    if (step === 1) {
      const t = setTimeout(() => setStep(2), 1800);
      return () => clearTimeout(t);
    }
  }, [step]);

  if (!open) return null;

  return (
    <div style={{
      position: 'absolute', inset: 0, zIndex: 100,
      background: '#0A0806',
      display: 'flex', flexDirection: 'column',
    }}>
      {/* Header */}
      <div style={{
        display: 'flex', justifyContent: 'space-between', alignItems: 'center',
        padding: '54px 16px 12px',
      }}>
        <button onClick={onClose} style={{
          width: 32, height: 32, borderRadius: 16,
          background: 'rgba(255,255,255,0.15)',
          border: 'none', cursor: 'pointer',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <Icon name="x" size={16} color="white" stroke={2} />
        </button>
        <span style={{
          fontFamily: TOKENS.fontSans, fontSize: 15, fontWeight: 600, color: 'white',
        }}>{step === 0 ? 'Beleg scannen' : step === 1 ? 'KI analysiert…' : 'Erfassungs-Formular'}</span>
        <button style={{
          width: 32, height: 32, borderRadius: 16,
          background: 'rgba(255,255,255,0.15)', border: 'none',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <Icon name="flash" size={15} color="white" stroke={2} />
        </button>
      </div>

      {step === 0 && <ScanStepCamera onCapture={() => setStep(1)} />}
      {step === 1 && <ScanStepProcessing />}
      {step === 2 && <ScanStepFields onDone={onClose} />}
    </div>
  );
}

function ScanStepCamera({ onCapture }) {
  return (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column' }}>
      <div style={{
        flex: 1, margin: 16, borderRadius: 12,
        background: `repeating-linear-gradient(
          45deg, #1C1815 0 12px, #15120F 12px 24px
        )`,
        position: 'relative', overflow: 'hidden',
      }}>
        {/* Doc mock */}
        <div style={{
          position: 'absolute', top: '18%', left: '12%', right: '12%', bottom: '22%',
          background: '#F5F1E8', borderRadius: 4, padding: 20,
          transform: 'rotate(-1.5deg)',
          boxShadow: '0 4px 20px rgba(0,0,0,0.4)',
        }}>
          <div style={{
            fontFamily: TOKENS.fontSans, fontSize: 10, fontWeight: 700,
            color: '#2A2520', marginBottom: 8,
          }}>GASAG AG</div>
          <div style={{
            fontFamily: TOKENS.fontMono, fontSize: 7, color: '#5B5446',
            lineHeight: 1.4,
          }}>Jahresrechnung 2025<br/>Kd: 84 712 394<br/>Bahnhofstr. 37</div>
          <div style={{
            marginTop: 14, paddingTop: 8, borderTop: '0.5px solid #D4CFC0',
            display: 'flex', justifyContent: 'space-between',
            fontFamily: TOKENS.fontMono, fontSize: 9, fontWeight: 600, color: '#2A2520',
          }}>
            <span>Betrag</span><span>4.127,84 €</span>
          </div>
        </div>

        {/* Detection corners */}
        {[[8,16],[92,16],[8,84],[92,84]].map(([x,y], i) => (
          <div key={i} style={{
            position: 'absolute', left: `${x}%`, top: `${y}%`,
            width: 22, height: 22,
            borderTop: x < 50 ? '3px solid #B8841F' : 'none',
            borderBottom: x < 50 ? 'none' : '3px solid #B8841F',
            borderLeft: y < 50 ? '3px solid #B8841F' : 'none',
            borderRight: y < 50 ? 'none' : '3px solid #B8841F',
            transform: 'translate(-50%, -50%)',
          }} />
        ))}
        <div style={{
          position: 'absolute', bottom: 16, left: 16, right: 16,
          padding: '8px 12px', background: 'rgba(0,0,0,0.6)', borderRadius: 8,
          backdropFilter: 'blur(10px)',
          fontFamily: TOKENS.fontSans, fontSize: 12, color: 'white',
          textAlign: 'center',
        }}>Beleg erkannt · ruhig halten</div>
      </div>
      <div style={{
        display: 'flex', justifyContent: 'center', alignItems: 'center',
        padding: '20px 0 40px',
      }}>
        <button onClick={onCapture} style={{
          width: 72, height: 72, borderRadius: 36,
          background: 'white', border: '4px solid rgba(255,255,255,0.4)',
          cursor: 'pointer', boxShadow: '0 4px 20px rgba(0,0,0,0.3)',
        }} />
      </div>
    </div>
  );
}

function ScanStepProcessing() {
  return (
    <div style={{
      flex: 1, display: 'flex', flexDirection: 'column',
      alignItems: 'center', justifyContent: 'center', gap: 24, padding: 40,
    }}>
      <div style={{
        width: 64, height: 64, borderRadius: 32,
        border: '3px solid rgba(255,255,255,0.2)',
        borderTopColor: '#B8841F',
        animation: 'spin 1s linear infinite',
      }} />
      <div style={{ textAlign: 'center' }}>
        <div style={{
          fontFamily: TOKENS.fontSans, fontSize: 16, fontWeight: 600, color: 'white',
          marginBottom: 6,
        }}>OCR-Volltext extrahieren</div>
        <div style={{
          fontFamily: TOKENS.fontSans, fontSize: 13, color: 'rgba(255,255,255,0.7)',
        }}>Versorger, Betrag, Zeitraum werden erkannt…</div>
      </div>
    </div>
  );
}

function ScanStepFields({ onDone }) {
  return (
    <div style={{
      flex: 1, background: TOKENS.bgApp,
      borderTopLeftRadius: 20, borderTopRightRadius: 20,
      overflow: 'auto', padding: '20px 16px 30px',
      display: 'flex', flexDirection: 'column', gap: 14,
    }}>
      <div style={{
        padding: '10px 12px', background: TOKENS.statusWarnSoft,
        borderRadius: 10, display: 'flex', gap: 8, alignItems: 'center',
      }}>
        <Icon name="warn" size={16} color={TOKENS.statusWarn} stroke={1.9} />
        <div style={{
          flex: 1,
          fontFamily: TOKENS.fontSans, fontSize: 12, color: TOKENS.statusWarn,
        }}>KI hat 5 Felder extrahiert. Bitte prüfen und validieren.</div>
      </div>

      <div>
        <label style={{
          fontFamily: TOKENS.fontSans, fontSize: 11, fontWeight: 600,
          color: TOKENS.textTertiary, letterSpacing: 0.5, textTransform: 'uppercase',
        }}>Dokumenttyp</label>
        <div style={{
          marginTop: 6, padding: '12px 14px',
          background: TOKENS.bgSurface,
          border: `1px solid ${TOKENS.separator}`, borderRadius: 10,
          display: 'flex', justifyContent: 'space-between', alignItems: 'center',
        }}>
          <span style={{
            fontFamily: TOKENS.fontSans, fontSize: 15, color: TOKENS.text,
          }}>Rechnung (Versorger)</span>
          <Icon name="chevronDown" size={14} color={TOKENS.textTertiary} stroke={2} />
        </div>
      </div>

      {[
        { l: 'Versorger', v: 'GASAG AG', conf: 98 },
        { l: 'Betrag', v: '4.127,84 €', conf: 99, mono: true },
        { l: 'Rechnungsdatum', v: '18.01.2026', conf: 97, mono: true },
        { l: 'Leistungszeitraum', v: '01.01.2025 – 31.12.2025', conf: 95, mono: true },
        { l: 'Kostenart (BetrKV)', v: 'Heizung & Warmwasser', conf: 82 },
      ].map((f, i) => (
        <div key={i}>
          <div style={{
            display: 'flex', justifyContent: 'space-between', alignItems: 'baseline',
          }}>
            <label style={{
              fontFamily: TOKENS.fontSans, fontSize: 11, fontWeight: 600,
              color: TOKENS.textTertiary, letterSpacing: 0.5, textTransform: 'uppercase',
            }}>{f.l}</label>
            <span style={{
              fontFamily: TOKENS.fontMono, fontSize: 10, color: TOKENS.statusWarn,
            }}>KI {f.conf}%</span>
          </div>
          <div style={{
            marginTop: 4, padding: '12px 14px',
            background: TOKENS.aiSuggestBg,
            border: `1px solid ${TOKENS.aiSuggest}`, borderRadius: 10,
            fontFamily: f.mono ? TOKENS.fontMono : TOKENS.fontSans,
            fontSize: 15, fontWeight: 500, color: TOKENS.text,
          }}>{f.v}</div>
        </div>
      ))}

      <button onClick={onDone} style={{
        marginTop: 6, padding: '14px',
        background: TOKENS.statusOk, color: 'white',
        border: 'none', borderRadius: 12,
        fontFamily: TOKENS.fontSans, fontSize: 15, fontWeight: 600,
        cursor: 'pointer',
        display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
      }}>
        <Icon name="checkCircle" size={18} color="white" stroke={1.9} />
        Speichern & validieren
      </button>
    </div>
  );
}

// ─── PDF preview sheet ─────────────────────────────────────
function PdfPreviewSheet({ open, onClose, unitId }) {
  if (!open) return null;
  const unit = UNITS.find(u => u.id === unitId);
  if (!unit) return null;
  const c = UNIT_COLOR[unitId];
  const factor = unitId === 'og' ? 1 : (unit.sqm / 128) * 0.92;
  const positions = ABRECHNUNG_OG.positions.filter(p => p.unitShare > 0).map(p => ({
    ...p, unitShare: p.unitShare * factor
  }));
  const total = positions.reduce((s, p) => s + p.unitShare, 0);
  const vz = unit.vorauszahlung * 12;
  const saldo = vz - total;

  return (
    <Sheet open={open} onClose={onClose} title="PDF Vorschau" height="92%">
      <div style={{ padding: '12px 12px', background: '#E8E4DA', minHeight: '100%' }}>
        {/* A4 page mock */}
        <div style={{
          background: 'white', padding: '24px 28px',
          boxShadow: '0 4px 16px rgba(0,0,0,0.08)',
          borderRadius: 2,
          fontFamily: '"Georgia", "Times New Roman", serif',
          color: '#1F2937', minHeight: 560,
        }}>
          {/* Letterhead */}
          <div style={{
            paddingBottom: 10, borderBottom: '2px solid #1F2937',
            marginBottom: 14,
          }}>
            <div style={{ fontSize: 9, color: '#6B7280', letterSpacing: 0.3 }}>
              Vermieter · Max Müller · Bahnhofstr. 37 · 12207 Berlin
            </div>
          </div>
          <div style={{ fontSize: 10, marginBottom: 18, lineHeight: 1.5 }}>
            {unit.tenant}<br/>
            {OBJEKT.address}, {unit.longLabel}<br/>
            {OBJEKT.city}
          </div>
          <div style={{ textAlign: 'right', fontSize: 9, color: '#6B7280', marginBottom: 18 }}>
            Berlin, 20.04.2026
          </div>
          <div style={{
            fontSize: 14, fontWeight: 700, marginBottom: 4,
          }}>Nebenkostenabrechnung {OBJEKT.periodShort}</div>
          <div style={{ fontSize: 10, color: '#6B7280', marginBottom: 16 }}>
            Abrechnungsperiode {OBJEKT.period} · {unit.longLabel} · {unit.sqm} m²
          </div>

          <div style={{ fontSize: 9 }}>
            <div style={{
              display: 'flex', fontWeight: 700, padding: '6px 0',
              borderBottom: '1px solid #1F2937',
            }}>
              <div style={{ flex: 1 }}>Position</div>
              <div style={{ width: 90, fontSize: 8, color: '#6B7280' }}>Schlüssel</div>
              <div style={{ width: 60, textAlign: 'right' }}>Anteil</div>
            </div>
            {positions.map((p, i) => (
              <div key={i} style={{
                display: 'flex', padding: '5px 0',
                borderBottom: '0.5px solid #E5E7EB',
              }}>
                <div style={{ flex: 1 }}>{p.label}</div>
                <div style={{ width: 90, fontSize: 8, color: '#6B7280' }}>{p.schluessel}</div>
                <div style={{ width: 60, textAlign: 'right', fontFamily: '"Courier New", monospace' }}>
                  {fmtEuro(p.unitShare)}
                </div>
              </div>
            ))}
            <div style={{
              display: 'flex', padding: '8px 0', fontWeight: 700,
              borderTop: '1px solid #1F2937', borderBottom: '1px solid #1F2937', marginTop: 4,
            }}>
              <div style={{ flex: 1 }}>Gesamte Nebenkosten</div>
              <div style={{ width: 60, textAlign: 'right', fontFamily: '"Courier New", monospace' }}>
                {fmtEuro(total)}
              </div>
            </div>
            <div style={{ display: 'flex', padding: '6px 0' }}>
              <div style={{ flex: 1 }}>Vorauszahlungen (12 × {fmtEuro(unit.vorauszahlung)})</div>
              <div style={{ width: 60, textAlign: 'right', fontFamily: '"Courier New", monospace' }}>
                − {fmtEuro(vz)}
              </div>
            </div>
            <div style={{
              display: 'flex', padding: '8px 0', fontWeight: 700, fontSize: 11,
              background: '#FAF8F1', marginTop: 4, padding: '8px 6px',
              color: saldo >= 0 ? '#3F7A5B' : '#A63D2A',
            }}>
              <div style={{ flex: 1 }}>{saldo >= 0 ? 'Guthaben für Mieter' : 'Nachzahlung durch Mieter'}</div>
              <div style={{ width: 60, textAlign: 'right', fontFamily: '"Courier New", monospace' }}>
                {saldo >= 0 ? '+' : '−'} {fmtEuro(Math.abs(saldo))}
              </div>
            </div>
          </div>

          <div style={{
            marginTop: 18, fontSize: 8, color: '#6B7280', lineHeight: 1.5,
          }}>
            Heizkosten nach §7 HeizkostenV (70/30). Einspruchsfrist 12 Monate (§556 Abs. 3 BGB).
            Handwerkerleistungen nach §35a EStG steuerlich absetzbar.
          </div>
        </div>

        {/* Actions */}
        <div style={{
          position: 'sticky', bottom: 0,
          padding: '16px 0 20px',
          display: 'flex', gap: 8,
        }}>
          <button style={{
            flex: 1, padding: '12px',
            background: TOKENS.accent, color: 'white',
            border: 'none', borderRadius: 10, cursor: 'pointer',
            fontFamily: TOKENS.fontSans, fontSize: 14, fontWeight: 600,
            display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
          }}>
            <Icon name="share" size={14} color="white" stroke={1.9} />
            Teilen
          </button>
          <button style={{
            flex: 1, padding: '12px',
            background: 'white', color: TOKENS.accent,
            border: `1px solid ${TOKENS.accent}`, borderRadius: 10, cursor: 'pointer',
            fontFamily: TOKENS.fontSans, fontSize: 14, fontWeight: 600,
            display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
          }}>
            <Icon name="mail" size={14} color={TOKENS.accent} stroke={1.9} />
            Per Mail
          </button>
          <button style={{
            flex: 1, padding: '12px',
            background: 'white', color: TOKENS.accent,
            border: `1px solid ${TOKENS.accent}`, borderRadius: 10, cursor: 'pointer',
            fontFamily: TOKENS.fontSans, fontSize: 14, fontWeight: 600,
            display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
          }}>
            <Icon name="printer" size={14} color={TOKENS.accent} stroke={1.9} />
            Drucken
          </button>
        </div>
      </div>
    </Sheet>
  );
}

Object.assign(window, { CompletenessSheet, ScanSheet, PdfPreviewSheet });
