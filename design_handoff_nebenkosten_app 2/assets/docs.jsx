// Documents + validation screen

function DocsScreen({ scope, onValidate, validatedDocs, onScan, onOpenDoc }) {
  const byMonth = {};
  DOCS.forEach(d => {
    const status = validatedDocs[d.id] || d.status;
    const key = d.month;
    if (!byMonth[key]) byMonth[key] = [];
    byMonth[key].push({...d, status});
  });
  const months = Object.keys(byMonth).sort().reverse();
  const monthLabel = (m) => {
    const [y, mo] = m.split('-');
    const names = ['Januar','Februar','März','April','Mai','Juni','Juli','August','September','Oktober','November','Dezember'];
    return `${names[parseInt(mo)-1]} ${y}`;
  };

  return (
    <div style={{ padding: '12px 16px 130px', display: 'flex', flexDirection: 'column', gap: 16 }}>
      {/* Scan CTA */}
      <button onClick={onScan} style={{
        display: 'flex', alignItems: 'center', gap: 12,
        padding: '14px 16px',
        background: TOKENS.accent, color: TOKENS.accentText,
        border: 'none', borderRadius: 14,
        cursor: 'pointer', textAlign: 'left',
      }}>
        <div style={{
          width: 36, height: 36, borderRadius: 18,
          background: 'rgba(255,255,255,0.15)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <Icon name="camera" size={20} color="white" stroke={1.8} />
        </div>
        <div style={{ flex: 1 }}>
          <div style={{
            fontFamily: TOKENS.fontSans, fontSize: 15, fontWeight: 600,
          }}>Beleg scannen</div>
          <div style={{
            fontFamily: TOKENS.fontSans, fontSize: 12, opacity: 0.8, marginTop: 1,
          }}>Foto → OCR → KI-Extraktion → Validierung</div>
        </div>
        <Icon name="chevronRight" size={16} color="white" stroke={2} />
      </button>

      {/* Legend */}
      <div style={{
        display: 'flex', gap: 10, padding: '10px 12px',
        background: TOKENS.bgSurfaceAlt, borderRadius: 10,
        border: `0.5px solid ${TOKENS.separator}`,
        justifyContent: 'space-between', alignItems: 'center',
      }}>
        <LegendItem color={TOKENS.statusMuted} label="Roh" />
        <LegendItem color={TOKENS.statusWarn} label="KI-Vorschlag" />
        <LegendItem color={TOKENS.statusOk} label="Validiert" />
      </div>

      {months.map(m => (
        <div key={m}>
          <SectionHeader style={{ marginBottom: 8 }}>{monthLabel(m)}</SectionHeader>
          <div style={{
            background: TOKENS.bgSurface,
            border: `0.5px solid ${TOKENS.separator}`,
            borderRadius: 14, overflow: 'hidden',
          }}>
            {byMonth[m].map((d, i) => (
              <DocRow key={d.id} d={d} last={i === byMonth[m].length - 1} onOpen={() => onOpenDoc(d.id)} />
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}

function LegendItem({ color, label }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 5, whiteSpace: 'nowrap', flexShrink: 0 }}>
      <div style={{ width: 8, height: 8, borderRadius: 4, background: color, flexShrink: 0 }} />
      <span style={{
        fontFamily: TOKENS.fontSans, fontSize: 11, color: TOKENS.textSecondary,
        whiteSpace: 'nowrap',
      }}>{label}</span>
    </div>
  );
}

function DocRow({ d, last, onOpen }) {
  const statusMap = {
    raw: { bg: 'rgba(138,133,120,0.14)', fg: TOKENS.statusMuted, label: 'Roh' },
    suggested: { bg: TOKENS.statusWarnSoft, fg: TOKENS.statusWarn, label: 'KI-Vorschlag' },
    validated: { bg: TOKENS.statusOkSoft, fg: TOKENS.statusOk, label: 'Validiert' },
  };
  const s = statusMap[d.status];
  return (
    <button onClick={onOpen} style={{
      display: 'flex', alignItems: 'center', gap: 12, width: '100%',
      padding: '12px 14px',
      borderBottom: last ? 'none' : `0.5px solid ${TOKENS.separator}`,
      background: 'transparent', border: 'none', cursor: 'pointer', textAlign: 'left',
    }}>
      <div style={{
        width: 40, height: 48, borderRadius: 4,
        background: s.bg, border: `1px solid ${s.fg}40`,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        flexShrink: 0,
      }}>
        <Icon name="doc" size={18} color={s.fg} stroke={1.6} />
      </div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{
          fontFamily: TOKENS.fontSans, fontSize: 14, fontWeight: 500, color: TOKENS.text,
          marginBottom: 3, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap',
        }}>{d.fileName}</div>
        <div style={{
          display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'nowrap',
        }}>
          <StatusPill status={d.status} label={s.label} />
          <span style={{
            fontFamily: TOKENS.fontMono, fontSize: 10, color: TOKENS.textTertiary,
            whiteSpace: 'nowrap',
          }}>{d.pages} S.</span>
        </div>
      </div>
      <Icon name="chevronRight" size={14} color={TOKENS.textQuaternary} stroke={2} />
    </button>
  );
}

// ─── Document validation screen ─────────────────────────────
function DocValidationSheet({ open, onClose, docId, validatedFields, onValidateField, onValidateAll }) {
  const doc = DOCS.find(d => d.id === docId);
  if (!doc) return null;
  const [rawExpanded, setRawExpanded] = useState(false);
  
  const bill = doc.linkedBill ? BILLS.find(b => b.id === doc.linkedBill) : null;
  
  // Mock extracted fields
  const fields = [
    { id: 'issuer', label: 'Versorger / Aussteller', value: bill?.issuer || '—', conf: doc.confidence.issuer || 0 },
    { id: 'amount', label: 'Betrag', value: bill ? fmtEuro(bill.amount) : '—', conf: doc.confidence.amount || 0, mono: true },
    { id: 'date', label: 'Rechnungsdatum', value: bill?.date || '—', conf: doc.confidence.date || 0, mono: true },
    { id: 'period', label: 'Leistungszeitraum', value: bill?.period || '—', conf: doc.confidence.period || 0, mono: true },
    { id: 'category', label: 'Kostenart (BetrKV)', value: bill?.category || '—', conf: 0.81 },
    { id: 'docnr', label: 'Belegnummer', value: bill?.docNr || '—', conf: 0.95, mono: true },
  ];

  return (
    <Sheet open={open} onClose={onClose} title={doc.fileName} height="92%">
      <div style={{ padding: '12px 16px 30px' }}>
        {/* Document preview */}
        <div style={{
          background: TOKENS.bgSurface, borderRadius: 12, overflow: 'hidden',
          border: `0.5px solid ${TOKENS.separator}`, marginBottom: 16,
        }}>
          <div style={{
            height: 120, background: `repeating-linear-gradient(
              135deg, ${TOKENS.bgSurfaceAlt} 0 10px,
              ${TOKENS.bgSurface} 10px 20px
            )`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            position: 'relative',
          }}>
            <Icon name="doc" size={36} color={TOKENS.textTertiary} stroke={1.4} />
            <div style={{
              position: 'absolute', bottom: 8, right: 8,
              padding: '4px 8px', background: 'rgba(0,0,0,0.5)', color: 'white',
              borderRadius: 6,
              fontFamily: TOKENS.fontMono, fontSize: 10,
            }}>{doc.pages} Seiten</div>
          </div>
        </div>

        {/* Level 1: Raw OCR */}
        <div style={{ marginBottom: 14 }}>
          <button onClick={() => setRawExpanded(!rawExpanded)} style={{
            display: 'flex', alignItems: 'center', gap: 8, width: '100%',
            padding: '10px 12px',
            background: TOKENS.bgSurfaceAlt, border: `0.5px solid ${TOKENS.separator}`,
            borderRadius: 10, cursor: 'pointer',
          }}>
            <Icon name={rawExpanded ? 'chevronDown' : 'chevronRight'} size={12}
              color={TOKENS.textSecondary} stroke={2.2} />
            <div style={{
              width: 8, height: 8, borderRadius: 4, background: TOKENS.statusMuted,
            }} />
            <span style={{
              flex: 1, textAlign: 'left',
              fontFamily: TOKENS.fontSans, fontSize: 12, fontWeight: 600,
              color: TOKENS.textSecondary, letterSpacing: 0.4, textTransform: 'uppercase',
            }}>Ebene 1 · Rohdaten (OCR-Volltext)</span>
          </button>
          {rawExpanded && (
            <div style={{
              marginTop: 6, padding: '12px 14px',
              background: '#2A2520', color: '#D4CFC0',
              borderRadius: 10,
              fontFamily: TOKENS.fontMono, fontSize: 10.5, lineHeight: 1.5,
              whiteSpace: 'pre-wrap', maxHeight: 160, overflow: 'auto',
            }}>
{`GASAG AG\nHolzmarktstraße 19–21\n10179 Berlin\n\nJahresrechnung Gaslieferung\nKd-Nr: 84 712 394\nLieferstelle: Bahnhofstr. 37, 12207 Berlin\n\nZeitraum: 01.01.2025 – 31.12.2025\nZählernr: 182-447-0091\nAnfangsstand: 382.471 kWh\nEndstand:    417.892 kWh\nVerbrauch:    35.421 kWh\n\nBetrag:      4.127,84 €\nfällig am:   15.02.2026\n...`}
            </div>
          )}
        </div>

        {/* Level 2: AI suggestion */}
        <div style={{
          padding: '6px 12px 10px',
          display: 'flex', alignItems: 'center', gap: 8,
        }}>
          <div style={{
            width: 8, height: 8, borderRadius: 4, background: TOKENS.statusWarn,
          }} />
          <span style={{
            fontFamily: TOKENS.fontSans, fontSize: 12, fontWeight: 600,
            color: TOKENS.statusWarn, letterSpacing: 0.4, textTransform: 'uppercase',
          }}>Ebene 2 · KI-Vorschlag</span>
          <span style={{
            marginLeft: 'auto',
            fontFamily: TOKENS.fontSans, fontSize: 11, color: TOKENS.textTertiary,
          }}>Tap zum Validieren</span>
        </div>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
          {fields.map(f => {
            const isValidated = validatedFields[`${docId}.${f.id}`] || false;
            return (
              <FieldRow key={f.id} field={f} validated={isValidated} 
                onValidate={() => onValidateField(docId, f.id)} />
            );
          })}
        </div>

        {/* Validate all CTA */}
        <button onClick={() => onValidateAll(docId, fields.map(f => f.id))} style={{
          marginTop: 20, width: '100%', padding: '14px',
          background: TOKENS.statusOk, color: 'white',
          border: 'none', borderRadius: 12,
          fontFamily: TOKENS.fontSans, fontSize: 15, fontWeight: 600,
          cursor: 'pointer',
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
        }}>
          <Icon name="checkCircle" size={18} color="white" stroke={1.9} />
          Alle Felder validieren & übernehmen
        </button>

        <div style={{
          marginTop: 12, padding: '10px 12px', background: TOKENS.bgSurface,
          borderRadius: 8, border: `0.5px solid ${TOKENS.separator}`,
          fontFamily: TOKENS.fontSans, fontSize: 11.5, color: TOKENS.textSecondary,
          lineHeight: 1.5,
        }}>
          <Icon name="info" size={12} color={TOKENS.textSecondary} stroke={1.8} />
          <span style={{ marginLeft: 6 }}>
            Erst nach Validierung fließen die Werte in die Abrechnung. Konfidenz &lt; 60 % muss geprüft werden.
          </span>
        </div>
      </div>
    </Sheet>
  );
}

function FieldRow({ field, validated, onValidate }) {
  const low = field.conf < 0.60;
  const state = validated ? 'validated' : (low ? 'lowConf' : 'suggested');
  const style = {
    suggested: { 
      bg: TOKENS.aiSuggestBg, border: TOKENS.aiSuggest, 
      label: TOKENS.aiSuggest, icon: 'warn' 
    },
    lowConf: { 
      bg: TOKENS.aiLowConfidenceBg, border: TOKENS.aiLowConfidence, 
      label: TOKENS.aiLowConfidence, icon: 'alert' 
    },
    validated: { 
      bg: TOKENS.aiValidatedBg, border: TOKENS.aiValidated, 
      label: TOKENS.aiValidated, icon: 'check' 
    },
  }[state];

  return (
    <button onClick={onValidate} disabled={validated} style={{
      display: 'flex', alignItems: 'center', gap: 12, width: '100%',
      padding: '12px 14px',
      background: style.bg,
      border: `1px solid ${style.border}`,
      borderRadius: 10, cursor: validated ? 'default' : 'pointer',
      textAlign: 'left',
      transition: 'all 0.2s',
    }}>
      <div style={{ flex: 1 }}>
        <div style={{
          display: 'flex', alignItems: 'center', gap: 6, marginBottom: 3,
        }}>
          <span style={{
            fontFamily: TOKENS.fontSans, fontSize: 11, fontWeight: 600,
            color: style.label, letterSpacing: 0.3, textTransform: 'uppercase',
          }}>{field.label}</span>
          <span style={{
            fontFamily: TOKENS.fontMono, fontSize: 10, color: style.label, opacity: 0.8,
          }}>·&nbsp;{Math.round(field.conf * 100)}% Konfidenz</span>
        </div>
        <div style={{
          fontFamily: field.mono ? TOKENS.fontMono : TOKENS.fontSans,
          fontSize: 15, fontWeight: 500, color: TOKENS.text,
        }}>{field.value}</div>
      </div>
      <div style={{
        width: 28, height: 28, borderRadius: 14,
        background: validated ? TOKENS.statusOk : 'rgba(255,255,255,0.6)',
        border: `1px solid ${style.border}`,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}>
        <Icon name={validated ? 'check' : (low ? 'alert' : 'check')} size={14} 
          color={validated ? 'white' : style.border} stroke={2.2} />
      </div>
    </button>
  );
}

Object.assign(window, { DocsScreen, DocValidationSheet });
