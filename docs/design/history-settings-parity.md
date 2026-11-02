# History and Settings parity audit

Source: `docs/design/approved-preview.html`, including the final container rules. Units are CSS pixels/native logical points. This records implementation targets and source corrections; final platform screenshot review is coordinated separately.

## History

| Selector | Exact target | Previous discrepancy and correction |
|---|---|---|
| `.history-page` | Paper; Source Sans 3 14 | Replaced platform-default UI typography |
| `.history-bar` | 68 high,12x20 padding; compact64,10x12 | Was72 and duplicated wrapper navbar; shared header and quiet unbordered Back/checkpoint |
| `.history-bar strong` | Source bold14; compact13 | Was Literata23; now Source bold70014/13 |
| `.history-bar small` | Muted Source,3px gap | Separate12pt subtitle baseline |
| `.history-timeline` | 240 wide;210 at601–850; compact fullwidth,max174 | Was256; now explicit breakpoints and complete panel |
| `.history-heading h2` | Literata22; compact Source600 13 | Was missing; Versions heading added |
| `.version-row` | Desktop18x20,left36; compact9x12,left28 | Was native16pt rows; explicit Source600 14 title |
| `.version-dot` | 6px accent outline,x19/x13 | Was missing; explicit outlined dot |
| `.version-row small`, `.version-kind` | Source12;compact11,inline | Was technical revision/actor text; readable date and type |
| `.version-head` | 26x28;compact18x16;medium20 horizontal | Explicit breakpoint padding |
| `.version-head h2` | Literata24/22 | Was26; corrected |
| `.version-head p` | Source14/12,1.5 leading | Empty note no longer reserves a blank block |
| `.segmented` | Panel,radius7,inset3;paper selected | Was bordered pills/native segment; local quiet segment buttons |
| `.segmented button` | Source13,6x10;compact12,6x8 | Explicit font; total desktop width224.3 |
| `.version-controls` | Side-by-side above850,stack below | Was always stacked |
| `.version-controls select` | max220 desktop,full compact | Explicit220/full bounds |
| `.read-only-label` | Muted Source12 | Was same serif18 as prose; now distinct attributed metadata |
| `.history-document h3` | Literata24/22,top16,bottom24 | Was same body style; distinct heading |
| `.history-document p` | Literata17/16,1.8 leading | Was18/default leading; now30.6/28.8 line height |
| `.diff-columns` | Two above850,stack below,gap24/16 | Medium now stacks |
| `.diff-columns p` | Literata15,1.7 leading | Was18; now15/25.5 |
| `.history-footer` | Source12 muted,12x28/12x16 | Was absent; local storage/restore status added |

Search is an existing native capability absent from the specimen: quiet magnifier beside the filter, collapsed by default. No-match copy is “No matching revisions.” to preserve the existing accessibility walkthrough. Persistent notes, safe restore backup, read-only snapshots, ID-based comparison, and working-only/deleted sections remain functional.

## Settings

| Selector | Exact target | Previous discrepancy and correction |
|---|---|---|
| `.settings-page .history-bar` | 68/64,Back,title,subtitle | Removed duplicate platform header; shared `closeSettings` callback |
| `.settings-content` | max760 centered,padding28x40;compact24x20 | Was fullwidth grouped table; now centered680 interior/compact width minus40 |
| `.settings-content > h2` | Literata28/25,bottom10 | Explicit sizes and content alignment |
| `.settings-section` | margin-top28 | Replaced native group spacing |
| `.settings-section h3` | Source600 13 muted,bottom12 | Explicit section labels |
| `.setting-row` | Horizontal,gap24/14,padding16 vertical,bottom1px line | Removed stacked regular controls and grouping |
| Row title | Source14 | Was17; corrected |
| `.setting-row small` | Muted Source12,1.5 leading,top4 | Was13; corrected size and shorter copy |
| Checkbox | Accent18x18 | Was large native switch; explicit checkbox drawing with native accessibility/input |
| Select | Auto width,max180;compact max145/font12;panel,lineborder,radius5 | Was stepper/large segments; quiet native-menu trigger |
| Primary Appearance | Dark appearance,Liquid Glass | System appearance moved to Advanced |
| Primary Writing | Text size,Line width,Check spelling | Extra typography rows moved to Advanced |
| Primary History | Automatic checkpoints,Browse version history | Actual persisted snapshot behavior retained |
| Primary Accessibility | Reduce motion,Reduce transparency | Exact ordering |
| `.settings-saved` | Source12 muted,top24 | Explicit immediate-application message |

Eight primary rows now follow the approved ordering. Existing editor font, line spacing, paragraph spacing, smart quotes, smart dashes, and word-count preferences remain under Advanced. System appearance and reset remain available. Controller search still exposes the entire14-setting catalog. Native wording differs only where preview-only text would misrepresent real persistence or live editing.

## Verification boundaries

Both platform-specific syntax checks pass. The retained `apple_history_settings_test` covers ID union, read-only comparison, editor selection, Trash preservation, History search, narrow bounds, Settings callback and search. Its row discovery was updated for the new ungrouped document. Checkpoint overlay coverage additionally verifies blank-title validation, multiline note persistence, dismissal and cancellation. The retained test passed after the dialog implementation. Final browser-computed geometry and native capture comparison remain pending; OS title bars, safe areas, menus and keyboards are platform surfaces outside the HTML specimen.

The measured regular History timeline row is101 points, and shared header title begins at106.1 points after a66.1-point quiet Back control. Compact reflow now refreshes attributed preview typography when crossing600 points. Appearance changes retain the Settings hierarchy, delegate one appearance update to the coordinator, and only replace glass when its appearance signature changes.
