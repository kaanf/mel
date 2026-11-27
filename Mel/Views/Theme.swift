import SwiftUI
import AppKit

/// Design tokens of the v2 design, taken 1:1 from the inline styles in `docs/design/v2/*.dc.html`.
/// The hex and opacity in each comment are the drawn Light value; each color also carries a Dark one (see `Color.init(hex:dark:)`).
/// Views use these, never literals. Each comment names the screen (id from `design/v2/FLOW.md`) and element.
/// Values are exact: two tokens share a value only where the design uses it for the same thing.
enum Theme {

    // MARK: - Colors

    enum Colors {
        // Text
        /// #1D1D1F · all screens: primary text, sidebar rows, toolbar title.
        static let label = Color(hex: 0x1D1D1F, dark: 0xF5F5F7)
        /// #6E6E73 · all screens: captions, sidebar status words, hints, toolbar subtitle.
        static let secondaryLabel = Color(hex: 0x6E6E73, dark: 0x98989D)
        /// #3A3A3C · A3 intro and file descriptions, B1 size notes, B6 issue text, C1 diff context.
        static let bodyLabel = Color(hex: 0x3A3A3C, dark: 0xD1D1D6)
        /// #AEAEB2 · disabled primary button fill (B1/A2/A4x Start), A4x "Untitled Spec", Locked dot, B3 bar when not running, B4 dashed MVP line.
        static let tertiary = Color(hex: 0xAEAEB2, dark: 0x636366)
        /// #0066D6 · all screens: text links ("Back to Setup", B4 "Answer 2 Questions").
        static let link = Color(hex: 0x0066D6, dark: 0x4DA3FF)
        /// #FFFFFF · text on accent buttons (A1 Continue, B4 Approve).
        static let onAccent = Color(hex: 0xFFFFFF, dark: 0xFFFFFF)

        // Surfaces
        /// #FFFFFF · window content, white buttons, cards, popovers.
        static let background = Color(hex: 0xFFFFFF, dark: 0x1E1E20)
        /// #F5F5F7 · grouped boxes: B4 "Before you approve", A3 file samples, B7 command block, B5 attachments.
        static let fill = Color(hex: 0xF5F5F7, dark: 0x2C2C2E)
        /// #FBFBFD · A2 drop zone, A4x unselected size card.
        static let fillSubtle = Color(hex: 0xFBFBFD, dark: 0x242426)
        /// rgba(0,0,0,0.03) · C4 search path field.
        static let fieldFill = Color.ink(0.03)
        /// rgba(0,0,0,0.04) · toolbar status pill (B2, B3, B4, B5).
        static let statusPillFill = Color.ink(0.04)
        /// rgba(0,0,0,0.05) · B1 unselected "Builds on" chips, A4x example chips.
        static let chipFill = Color.ink(0.05)
        /// rgba(0,0,0,0.06) · B4 "P1 · MVP" badge, A3 segmented control track, B1 icon well.
        static let badgeFill = Color.ink(0.06)
        /// rgba(0,0,0,0.08) · selected sidebar row, B4 Preview/Markdown selected segment, B2 progress track.
        static let selectionFill = Color.ink(0.08)
        /// rgba(0,0,0,0.12) · switch track off (B1, B7, C4).
        static let switchOffFill = Color.ink(0.12)
        /// #F6F6F8 · sidebar panel (B2–C3): the design's rgba(245,245,247,0.86) over the white window, as WebKit draws it.
        static let sidebarPanel = Color(hex: 0xF6F6F8, dark: 0x28282A)
        /// rgba(255,255,255,0.8) · toolbar glass groups (B1–B5). macOS 26 draws toolbar glass; reference value.
        static let toolbarGlass = Color(hex: 0xFFFFFF, opacity: 0.8, dark: 0xFFFFFF, darkOpacity: 0.8)
        /// rgba(255,255,255,0.22) · ⌘↩ / ↩ key hint on accent buttons (A1, A3, B1, B4).
        static let keyHintOnAccent = Color(hex: 0xFFFFFF, opacity: 0.22, dark: 0xFFFFFF, darkOpacity: 0.22)

        // Accent
        /// #007AFF · primary buttons, selection rings, switch on, radio on, active step.
        static let accent = Color(hex: 0x007AFF, dark: 0x0A84FF)
        /// rgba(0,122,255,0.08) · selected chip and size card (B1, A4x).
        static let accentSelectedFill = Color(hex: 0x007AFF, opacity: 0.08, dark: 0x0A84FF, darkOpacity: 0.136)
        /// rgba(0,122,255,0.06) · B4 suggestion box, C1 new decision, A2 drop zone with a folder.
        static let accentTint = Color(hex: 0x007AFF, opacity: 0.06, dark: 0x0A84FF, darkOpacity: 0.102)
        /// rgba(0,122,255,0.3) · outline of `accentTint` boxes (B4 suggestion, C1 new decision).
        static let accentOutline = Color(hex: 0x007AFF, opacity: 0.3, dark: 0x0A84FF, darkOpacity: 0.51)

        // Separators (0.5 pt lines)
        /// rgba(0,0,0,0.1) · list separators (A1, B2, B3, B4 "Before you approve"), inspector left edge.
        static let separator = Color.ink(0.1)
        /// rgba(0,0,0,0.08) · sidebar footer top edge (B2–B4), A3 rows, A1x and C4 section bottoms.
        static let separatorLight = Color.ink(0.08)
        /// rgba(0,0,0,0.07) · table rows in B6 Analyze, B7 tasks, C1 affected files.
        static let separatorTable = Color.ink(0.07)
        /// rgba(0,0,0,0.06) · B1 form section edges, B5 table, A4x footer.
        static let separatorFaint = Color.ink(0.06)
        /// rgba(0,0,0,0.15) · vertical divider between toolbar controls (B3, C4).
        static let toolbarDivider = Color.ink(0.15)
        /// rgba(0,0,0,0.2) · 16 pt connector line between steps (B2, B3).
        static let stepConnector = Color.ink(0.2)

        // Status
        /// #248A3D · check marks, Approved dot, B6 "✓" cell.
        static let success = Color(hex: 0x248A3D, dark: 0x30D158)
        /// rgba(36,138,61,0.1) · B1 "Context ready" badge fill.
        static let successBadgeFill = Color(hex: 0x248A3D, opacity: 0.1, dark: 0x30D158, darkOpacity: 0.17)
        /// #1B6E30 · B1 "Context ready" badge text.
        static let successBadgeText = Color(hex: 0x1B6E30, dark: 0x6FE08C)
        /// #B25000 · Out of date dot (C1, Rerun), B6 quality/scope issue dot.
        static let warning = Color(hex: 0xB25000, dark: 0xFF9F0A)
        /// rgba(178,80,0,0.1) · B1 "No context yet" badge fill.
        static let warningBadgeFill = Color(hex: 0xB25000, opacity: 0.1, dark: 0xFF9F0A, darkOpacity: 0.17)
        /// #8A3D00 · B1 "No context yet" badge text.
        static let warningBadgeText = Color(hex: 0x8A3D00, dark: 0xFFC266)
        /// #C93400 · B6 issues dot and contradiction, B5 missing-state outline, C2 warning glyph.
        static let caution = Color(hex: 0xC93400, dark: 0xFF6B3D)
        /// #A52A00 · B5 "Missing" badge text, B6 Missing / Conflict cells.
        static let cautionText = Color(hex: 0xA52A00, dark: 0xFF9272)
        /// #D70015 · C2 stopped file mark.
        static let failure = Color(hex: 0xD70015, dark: 0xFF453A)
        /// #8944AB · B3 progress bar while the agent runs.
        static let drafting = Color(hex: 0x8944AB, dark: 0xBF5AF2)

        // C1 Refine
        /// #FFF4E5 · C1 "You changed an approved file" banner.
        static let bannerFill = Color(hex: 0xFFF4E5, dark: 0x3A2B14)
        /// rgba(178,80,0,0.35) · C1 banner outline.
        static let bannerOutline = Color(hex: 0xB25000, opacity: 0.35, dark: 0xFF9F0A, darkOpacity: 0.595)
        /// rgba(215,0,21,0.07) · C1 diff, removed line.
        static let diffRemovedFill = Color(hex: 0xD70015, opacity: 0.07, dark: 0xFF453A, darkOpacity: 0.119)
        /// #86000F · C1 diff, removed line text.
        static let diffRemovedText = Color(hex: 0x86000F, dark: 0xFF8A80)
        /// rgba(36,138,61,0.09) · C1 diff, added line.
        static let diffAddedFill = Color(hex: 0x248A3D, opacity: 0.09, dark: 0x30D158, darkOpacity: 0.153)
        /// #155724 · C1 diff, added line text.
        static let diffAddedText = Color(hex: 0x155724, dark: 0x7EE2A0)
    }

    // MARK: - Text

    /// Size, weight and line height of one text style. Apply with `.textStyle(_:)`.
    struct TextStyle: Sendable {
        let size: CGFloat
        let weight: Font.Weight
        /// nil keeps the font's own line height (the design sets none).
        let lineHeight: CGFloat?
        var design: Font.Design = .default
        /// letter-spacing in points (em × size).
        var tracking: CGFloat = 0

        var font: Font { .system(size: size, weight: weight, design: design) }

        /// How far to move the glyphs down so they sit in the line box like CSS (half the extra
        /// leading above, half below). `.lineHeight(.exact)` puts all of it below.
        var glyphShift: CGFloat {
            guard let lineHeight, let naturalHeight else { return 0 }
            return (lineHeight - naturalHeight) / 2
        }

        /// The font's own line height as SwiftUI lays it out (see `measuredHeight`).
        var naturalHeight: CGFloat? { Self.measuredHeight[Key(size: size, mono: design == .monospaced)] }

        struct Key: Hashable { let size: CGFloat; let mono: Bool }

        /// Per font size: the line height at which SwiftUI and WebKit place the glyphs alike.
        /// Measured at 8× against the `.dc.html` renderer (WebKit); weight changes it by under 0.07 pt.
        static let measuredHeight: [Key: CGFloat] = [
            Key(size: 10, mono: false): 12.125, Key(size: 11, mono: false): 13.5, Key(size: 12, mono: false): 14.75,
            Key(size: 13, mono: false): 15.875, Key(size: 14, mono: false): 17.125, Key(size: 15, mono: false): 18.25,
            Key(size: 17, mono: false): 20.875, Key(size: 22, mono: false): 27.125, Key(size: 26, mono: false): 32.25,
            Key(size: 28, mono: false): 34.875, Key(size: 30, mono: false): 37.375,
            Key(size: 10, mono: true): 13.125, Key(size: 11, mono: true): 14.625, Key(size: 12, mono: true): 15.75,
        ]
    }

    enum Text {
        /// 30/36 bold, -0.02em · A1 "Welcome to Mel", B1 and A4x title.
        static let largeTitle = TextStyle(size: 30, weight: .bold, lineHeight: 36, tracking: -0.6)
        /// 28/34 bold, -0.02em · A2, A3, C3 title.
        static let title1 = TextStyle(size: 28, weight: .bold, lineHeight: 34, tracking: -0.56)
        /// 26/32 bold, -0.02em · B4 "Requirements", B5, B7, A1x, A1 second layer title.
        static let title2 = TextStyle(size: 26, weight: .bold, lineHeight: 32, tracking: -0.52)
        /// 22/28 bold, -0.01em · B6 "Analyze" title.
        static let title3 = TextStyle(size: 22, weight: .bold, lineHeight: 28, tracking: -0.22)
        /// 17/22 semibold · B4 story heading, B5 section, C2 heading.
        static let headline = TextStyle(size: 17, weight: .semibold, lineHeight: 22)
        /// 17/22 bold · B3 live preview title.
        static let headlineBold = TextStyle(size: 17, weight: .bold, lineHeight: 22)
        /// 15/23 · A1, B1, A4x lead paragraph.
        static let lead = TextStyle(size: 15, weight: .regular, lineHeight: 23)
        /// 15/19 semibold · toolbar file title (B2–B6).
        static let toolbarTitle = TextStyle(size: 15, weight: .semibold, lineHeight: 19)
        /// 15/20 semibold · A2 and C2 section title.
        static let sectionTitle = TextStyle(size: 15, weight: .semibold, lineHeight: 20)
        /// 14/21 · A2, A3, B7, C3 intro paragraph.
        static let intro = TextStyle(size: 14, weight: .regular, lineHeight: 21)
        /// 14/18 semibold · B1 project pop-up.
        static let cardTitle = TextStyle(size: 14, weight: .semibold, lineHeight: 18)
        /// 13/20 · B4 story text and criteria.
        static let prose = TextStyle(size: 13, weight: .regular, lineHeight: 20)
        /// 13/19 · A3, B6, C1, A1x longer explanations.
        static let bodyLoose = TextStyle(size: 13, weight: .regular, lineHeight: 19)
        /// 13/18 · all screens: body, sidebar rows, buttons.
        static let body = TextStyle(size: 13, weight: .regular, lineHeight: 18)
        /// 13/18 medium · selected sidebar row, B2 option title.
        static let bodyMedium = TextStyle(size: 13, weight: .medium, lineHeight: 18)
        /// 13/18 semibold · primary button labels, box headings ("Before you approve").
        static let bodyBold = TextStyle(size: 13, weight: .semibold, lineHeight: 18)
        /// 12/17 · A3, B3, C1 small paragraphs.
        static let calloutLoose = TextStyle(size: 12, weight: .regular, lineHeight: 17)
        /// 12/16 · all screens: secondary lines, status pill text, links in rows.
        static let callout = TextStyle(size: 12, weight: .regular, lineHeight: 16)
        /// 12/16 medium · A3 segmented selected, B4–C1 table labels.
        static let calloutMedium = TextStyle(size: 12, weight: .medium, lineHeight: 16)
        /// 12/16 semibold · B1–B5 small headings.
        static let calloutBold = TextStyle(size: 12, weight: .semibold, lineHeight: 16)
        /// 11/15 · A1x install hint.
        static let captionLoose = TextStyle(size: 11, weight: .regular, lineHeight: 15)
        /// 11/14 · all screens: captions, sidebar status words, toolbar subtitle.
        static let caption = TextStyle(size: 11, weight: .regular, lineHeight: 14)
        /// 11/14 medium · key hints (⌘↩), B1 context badge.
        static let captionMedium = TextStyle(size: 11, weight: .medium, lineHeight: 14)
        /// 11/14 semibold · sidebar section header "Specs", "P1 · MVP" badge, B5 "Missing" badge.
        static let captionBold = TextStyle(size: 11, weight: .semibold, lineHeight: 14)
        /// 11 (no line height) · B5 flow diagram caption.
        static let diagramCaption = TextStyle(size: 11, weight: .regular, lineHeight: nil)
        /// 10/13 semibold · B7 file tile label.
        static let micro = TextStyle(size: 10, weight: .semibold, lineHeight: 13)

        // SF Mono
        /// 12/20 mono · B4 criterion ids ("1.1") and Markdown view.
        static let codeProse = TextStyle(size: 12, weight: .regular, lineHeight: 20, design: .monospaced)
        /// 12/19 mono · C1 diff lines.
        static let codeDiff = TextStyle(size: 12, weight: .regular, lineHeight: 19, design: .monospaced)
        /// 12/18 mono · B4 Markdown, B7 command block.
        static let codeBlock = TextStyle(size: 12, weight: .regular, lineHeight: 18, design: .monospaced)
        /// 12/16 mono · B3, B4, B6, B7, C2 file names and paths.
        static let code = TextStyle(size: 12, weight: .regular, lineHeight: 16, design: .monospaced)
        /// 12/16 semibold mono · A3 and C1 file names.
        static let codeBold = TextStyle(size: 12, weight: .semibold, lineHeight: 16, design: .monospaced)
        /// 11/18 mono · B3 activity log.
        static let codeLog = TextStyle(size: 11, weight: .regular, lineHeight: 18, design: .monospaced)
        /// 11/15 mono · A1x install command, B7 terminal command.
        static let codeCaptionLoose = TextStyle(size: 11, weight: .regular, lineHeight: 15, design: .monospaced)
        /// 11/15 semibold mono · B7 task number.
        static let codeCaptionBold = TextStyle(size: 11, weight: .semibold, lineHeight: 15, design: .monospaced)
        /// 11/14 mono · paths and ids in captions (A1, A3, B1–B3).
        static let codeCaption = TextStyle(size: 11, weight: .regular, lineHeight: 14, design: .monospaced)
        /// 10/13 mono · B1 and B5 small ids.
        static let codeMicro = TextStyle(size: 10, weight: .regular, lineHeight: 13, design: .monospaced)
        /// 10 mono (no line height) · B5 flow diagram criterion ids.
        static let codeDiagram = TextStyle(size: 10, weight: .regular, lineHeight: nil, design: .monospaced)
    }

    // MARK: - Spacing

    /// Gaps, padding and margins. Named by value: the design uses each value in many places.
    enum Space {
        /// 1 · gap between sidebar rows.
        static let x1: CGFloat = 1
        /// 2 · gap inside toolbar glass groups, padding of segmented tracks.
        static let x2: CGFloat = 2
        /// 3 · B1 size card title-to-note gap.
        static let x3: CGFloat = 3
        /// 4 · sidebar row leading padding (spec row), small stacks.
        static let x4: CGFloat = 4
        /// 5 · key hint horizontal padding (⌘↩).
        static let x5: CGFloat = 5
        /// 6 · sidebar row icon gap, caption stacks.
        static let x6: CGFloat = 6
        /// 7 · "P1 · MVP" badge horizontal padding.
        static let x7: CGFloat = 7
        /// 8 · sidebar inset and row padding, most gaps.
        static let x8: CGFloat = 8
        /// 9 · B2 question card vertical padding.
        static let x9: CGFloat = 9
        /// 10 · toolbar gap, box vertical padding.
        static let x10: CGFloat = 10
        /// 12 · box horizontal padding, toolbar trailing padding, list row padding.
        static let x12: CGFloat = 12
        /// 14 · article gap (B4), status pill padding, A3/B6 box padding.
        static let x14: CGFloat = 14
        /// 16 · B4/B5 section gaps, card padding, button padding.
        static let x16: CGFloat = 16
        /// 18 · sidebar section header leading padding, C1 gaps.
        static let x18: CGFloat = 18
        /// 20 · toolbar leading padding, content top padding (B4), B2/B3 columns gap.
        static let x20: CGFloat = 20
        /// 22 · A1/A3 vertical stack gap, A1x button padding.
        static let x22: CGFloat = 22
        /// 24 · B1/B2 content horizontal padding, A2 drop zone padding.
        static let x24: CGFloat = 24
        /// 26 · leading padding of file rows in the sidebar (indent under the spec).
        static let x26: CGFloat = 26
        /// 28 · C3 column gap, B5 margin.
        static let x28: CGFloat = 28
        /// 32 · content horizontal padding (B4–C1), bottom padding (B2, B3, A3).
        static let x32: CGFloat = 32
        /// 40 · content bottom padding (B1, B4–C1), A1/A3 window padding.
        static let x40: CGFloat = 40
        /// 48 · C4 indented settings rows.
        static let x48: CGFloat = 48
        /// 72 · C3 top padding.
        static let x72: CGFloat = 72
    }

    // MARK: - Sizes

    /// Fixed dimensions of shared parts and controls.
    enum Size {
        /// 1280 × 800 · window size every screen is drawn at (default size of the main window).
        static let windowWidth: CGFloat = 1280
        static let windowHeight: CGFloat = 800
        /// 232 · sidebar width (B2–C2).
        static let sidebarWidth: CGFloat = 232
        /// 28 · sidebar row and segmented button height.
        static let sidebarRow: CGFloat = 28
        /// 8 · status dot in sidebar rows and the toolbar pill.
        static let statusDot: CGFloat = 8
        /// 1.5 · ring width of hollow status dots (Review, Edited, Locked).
        static let statusDotStroke: CGFloat = 1.5
        /// Dash pattern of the Locked dot: CSS `1.5px dashed` as WebKit draws it on an 8 pt circle,
        /// two 4.5 pt dashes (lower left and top) over the 20.42 pt turn; the phase starts the first at 95°.
        static let statusDotDash: [CGFloat] = [4.5, 3.1, 4.5, 8.32]
        static let statusDotDashPhase: CGFloat = -5.44
        /// 52 · toolbar height (B2–C2).
        static let toolbar: CGFloat = 52
        /// 130 · minimum width of the toolbar title column.
        static let toolbarTitleMinWidth: CGFloat = 130
        /// Maximum width of the toolbar status pill; the design sets one per screen.
        /// 360 · B2 Intake.
        static let statusPillIntake: CGFloat = 360
        /// 340 · B3 Drafting.
        static let statusPillDrafting: CGFloat = 340
        /// 320 · B5 Review EXPERIENCE.md.
        static let statusPillExperience: CGFloat = 320
        /// 300 · B4 Review.
        static let statusPillReview: CGFloat = 300
        /// 160 · the pill with its short text ("Needs you", "Running") in a narrow window; not drawn.
        static let statusPillCompact: CGFloat = 160
        /// 44 · title bar row: sidebar top (traffic lights), A2/A3/A4x bar with the centered title.
        static let titleBar: CGFloat = 44
        /// 52 · a column's header row (title, status, actions), where the window toolbar was.
        static let columnHeader: CGFloat = 52
        /// 15 · Project context house icon; 12 · spec row chevron; 14 · New Spec plus.
        static let projectIcon: CGFloat = 15
        static let chevron: CGFloat = 12
        static let plusIcon: CGFloat = 14
        /// 12 · the Settings gear at the end of the sidebar's agent line; not drawn.
        static let sidebarGear: CGFloat = 12
        /// 14 · "Needs you" alert icon in the toolbar pill (B2).
        static let alertIcon: CGFloat = 14
        /// 96 · logo on A1 and A1x; 56 · its top on A1 (absolute, centered).
        static let logoLarge: CGFloat = 96
        static let welcomeLogoTop: CGFloat = 56
        /// A1: content column 520 wide, 176 from the top; subtitle max 420.
        static let welcomeWidth: CGFloat = 520
        static let welcomeContentTop: CGFloat = 176
        static let welcomeTextWidth: CGFloat = 420
        /// A1x: column 540 wide; text max 440.
        static let noAgentWidth: CGFloat = 540
        static let noAgentTextWidth: CGFloat = 440
        /// 52 · agent row (A1); 30 · its dark tile; 16 · terminal glyph; 14 · Ready check.
        static let agentRow: CGFloat = 52
        static let agentTile: CGFloat = 30
        static let terminalIcon: CGFloat = 16
        static let checkIcon: CGFloat = 14
        /// A2: column 680 wide; drop zone min 180 with a 40 pt icon; repo rows min 40.
        static let pickProjectWidth: CGFloat = 680
        static let dropZone: CGFloat = 180
        static let dropIcon: CGFloat = 40
        static let repoRow: CGFloat = 40
        /// A3: column 760 wide, intro max 600; folder row 48 with an 18 pt icon; context cards min 330 wide; 12 · read-list check.
        static let projectSetupWidth: CGFloat = 760
        static let projectSetupTextWidth: CGFloat = 600
        static let folderRow: CGFloat = 48
        static let folderIcon: CGFloat = 18
        static let contextCardMin: CGFloat = 330
        static let smallCheck: CGFloat = 12
        /// B1: column max 620; logo 32; project row min 52 (18 pt folder); Quick fix field rows min 38 with a
        /// 104 pt label; settings rows 44 (switch row min 52); settings button folder 15; Ready check 10;
        /// pop-up arrows drawn 9 × 11; paperclip 13; evidence remove button 18 with an 8 pt cross; topic dot 6.
        static let newSpecWidth: CGFloat = 620
        static let logoSmall: CGFloat = 32
        static let projectRow: CGFloat = 52
        static let bugRow: CGFloat = 38
        static let bugLabelWidth: CGFloat = 104
        static let settingsRow: CGFloat = 44
        static let buttonFolderIcon: CGFloat = 15
        static let readyCheck: CGFloat = 10
        static let popUpWidth: CGFloat = 9
        static let popUpHeight: CGFloat = 11
        /// 8 · arrows of the B1 project pop-up (the mock's native <select>).
        static let selectArrowWidth: CGFloat = 8
        static let paperclipIcon: CGFloat = 13
        static let removeButton: CGFloat = 18
        static let removeIcon: CGFloat = 8
        static let topicDot: CGFloat = 6
        /// 36 × 32 · B1 Settings button (toolbar glass group) with a 16 pt gear.
        static let toolbarIconButton: CGFloat = 36
        static let settingsIcon: CGFloat = 16
        /// 6 rows · B1 idea text area.
        static let ideaLines = 6
        /// B2: column max 560; answered row 36; inspector 272 wide; Understanding bar 5 high; inspector rows 28 / 32;
        /// answered chevron 10; inspector icon 12.
        static let intakeWidth: CGFloat = 560
        static let answeredRow: CGFloat = 36
        static let inspectorWidth: CGFloat = 272
        static let understandingBar: CGFloat = 5
        static let coverageRow: CGFloat = 28
        static let inspectorRow: CGFloat = 32
        static let rowChevron: CGFloat = 10
        /// 3 lines · B2 answer field of an open question (not drawn; the note field's look, taller).
        static let openAnswerLines = 3
        /// B3: live preview 300 wide; step rows min 36 with a 14 pt icon box (13 pt check); Up Next rows 40 with a 13 pt lock.
        static let livePreviewWidth: CGFloat = 300
        static let stepRow: CGFloat = 36
        static let stepIcon: CGFloat = 14
        static let stepCheck: CGFloat = 13
        static let upNextRow: CGFloat = 40
        /// 2 × 13 · B3 live preview caret.
        static let caretWidth: CGFloat = 2
        /// B4: criterion id column 24; "Before you approve" rows min 30 with 13 pt icons.
        static let criterionID: CGFloat = 24
        static let checklistRow: CGFloat = 30
        static let checklistIcon: CGFloat = 13
        /// B5: article max 640; flow node min 96 wide; flow arrow 18; branch rows indented 112 with a 16 pt glyph;
        /// states table columns 130 (screen) and 64 (criteria); state chips 20 high.
        static let experienceMaxWidth: CGFloat = 640
        static let flowNodeMin: CGFloat = 96
        static let flowArrow: CGFloat = 18
        static let branchIndent: CGFloat = 112
        static let screenColumn: CGFloat = 130
        static let criteriaColumn: CGFloat = 64
        /// B6: content max 900; stat tiles min 190; coverage columns 52 (ID) and 84 (each mark).
        static let analyzeMaxWidth: CGFloat = 900
        static let statTileMin: CGFloat = 190
        static let coverageID: CGFloat = 52
        static let coverageCell: CGFloat = 84
        /// B7: column 760; file tiles min 140; task number column 22; ready icon 20; task priority badge 18 high.
        static let specReadyWidth: CGFloat = 760
        static let fileTileMin: CGFloat = 140
        static let taskNumber: CGFloat = 22
        static let readyIcon: CGFloat = 20
        static let priorityBadge: CGFloat = 18
        /// C1: column 640; banner icon 18; impact rows min 46; decisions column 288; "Why" field 2 lines.
        static let refineMaxWidth: CGFloat = 640
        static let bannerIcon: CGFloat = 18
        static let impactRow: CGFloat = 46
        static let decisionsWidth: CGFloat = 288
        static let whyLines = 2
        /// C2: dialog 520 wide; logo 52 with a 24 pt alert badge (white disc 22) at its lower right.
        static let dialogWidth: CGFloat = 520
        static let dialogLogo: CGFloat = 52
        static let alertBadge: CGFloat = 24
        /// C3: column 680, intro max 560; how-it-works tiles min 140; start cards min 190.
        static let homeWidth: CGFloat = 680
        static let homeTextWidth: CGFloat = 560
        static let homeStepMin: CGFloat = 140
        static let homeStartMin: CGFloat = 190
        /// C4: window 640; agent row 48 with a 26 pt tile (radius 6, 14 pt glyph), detail rows 36 indented 48 with a 72 pt label;
        /// search path rows 26, list footer 24 with 28 pt +/− buttons and 12 pt glyphs.
        static let settingsWidth: CGFloat = 680
        static let agentCardRow: CGFloat = 48
        static let agentCardTile: CGFloat = 26
        static let agentDetailRow: CGFloat = 36
        static let agentDetailIndent: CGFloat = 48
        static let agentDetailLabel: CGFloat = 72
        static let pathRow: CGFloat = 26
        static let pathFooter: CGFloat = 24
        static let pathButton: CGFloat = 28
        /// 2 · progress bar along the bottom of the toolbar pill (B3).
        static let progressBar: CGFloat = 2
        /// 620 · maximum width of the review article (B4, B5).
        static let articleMaxWidth: CGFloat = 620
        /// 0.5 · separators and hairline rings.
        static let hairline: CGFloat = 0.5
        /// 33 · leading inset of separators in the B4 "Before you approve" list.
        static let checklistSeparatorInset: CGFloat = 33
        /// 35 · leading inset of separators in the B3 step list and C2 file list.
        static let stepSeparatorInset: CGFloat = 35

        // Control heights
        /// 34 · large buttons (A1 Continue, A3, B1 Start, C1 Refine).
        static let buttonLarge: CGFloat = 34
        /// 32 · toolbar buttons and glass groups (B4 Approve, B6, C1).
        static let buttonToolbar: CGFloat = 32
        /// 30 · B1 "Builds on" chips, toolbar status pill, B4 checklist rows.
        static let chip: CGFloat = 30
        /// 28 · regular buttons (B2 Continue / Decide Later, B3, B7, C2).
        static let button: CGFloat = 28
        /// 26 · small buttons (A3 Change…, B1 Read Repo), C4 path field.
        static let buttonSmall: CGFloat = 26
        /// 24 · mini buttons (A3 Add Rule, segmented items, sidebar New Spec).
        static let buttonMini: CGFloat = 24
        /// 22 · B4 inspector tabs, B4 Reject, B1 context badge.
        static let buttonTiny: CGFloat = 22
        /// 20 · badges ("P1 · MVP", B5 Missing).
        static let badge: CGFloat = 20
        /// 36 · width of B4 toolbar segment buttons.
        static let toolbarSegmentWidth: CGFloat = 36
        /// 32 × 18 · switch track; knob 14.
        static let switchWidth: CGFloat = 32
        static let switchHeight: CGFloat = 18
        static let switchKnob: CGFloat = 14
        /// 14 · B2 option radio; inner dot 6.
        static let radio: CGFloat = 14
        static let radioDot: CGFloat = 6
    }

    // MARK: - Radii

    /// Corner radii of rounded rectangles. Pills (radius = height / 2) use `Capsule()`.
    enum Radius {
        /// 3 · B2 progress track (5 pt high).
        static let progress: CGFloat = 3
        /// 4 · key hint (⌘↩), B2 option key and "Suggested" tag, C3 placeholder bars.
        static let keyHint: CGFloat = 4
        /// 5 · C2 progress bar (10 pt high).
        static let progressLarge: CGFloat = 5
        /// 6 · code chips and command blocks (A3, A1x, B5, B7), B1 icon button.
        static let code: CGFloat = 6
        /// 7 · fields and pop-up buttons (B1, B2 note field, C4 menu, A1 agent icon).
        static let field: CGFloat = 7
        /// 8 · sidebar rows, B3 preview, B4 suggestion box, B5 attachments, C4 agent rows.
        static let row: CGFloat = 8
        /// 10 · boxes: B4 "Before you approve", B2 coverage, B3 steps, B5 tables.
        static let box: CGFloat = 10
        /// 12 · cards and the sidebar panel: A3 file list, B1 size cards, B6, B7, C1 banner, C3 cards.
        static let card: CGFloat = 12
        /// 14 · A1 agent list, B1 form box.
        static let panel: CGFloat = 14
        /// 16 · A2 drop zone, C2 dialog, C4 window content.
        static let large: CGFloat = 16
    }

    // MARK: - Elevation

    /// One CSS shadow layer: `x 0, y, blur, color`.
    struct Drop: Sendable {
        let y: CGFloat
        let blur: CGFloat
        let color: Color
        /// SwiftUI shadow radius for a CSS blur (σ = blur / 2).
        var radius: CGFloat { blur / 2 }
    }

    /// Hairline ring (`box-shadow: 0 0 0 width color`, optionally `inset`) plus at most one shadow.
    struct Elevation: Sendable {
        var ring: Color?
        var ringWidth: CGFloat = 0.5
        var insetRing = false
        var drop: Drop?
        var innerDrop: Drop?

        // Raised controls (outer ring + drop)
        /// Large accent button: A1 Continue, A3 Save and Start a Spec, B1 Start, C1 Refine 3 Files.
        static let primaryLarge = Elevation(ring: .ink(0.08), drop: Drop(y: 1, blur: 3, color: .black.opacity(0.12)))
        /// Toolbar accent button: B4/B5 Approve, B6 Fix n Issues.
        static let primaryToolbar = Elevation(ring: .ink(0.08), drop: Drop(y: 1, blur: 4, color: .black.opacity(0.12)))
        /// Regular accent button: B2 Continue, C2 main action.
        static let primary = Elevation(ring: .ink(0.08), drop: Drop(y: 1, blur: 2, color: .black.opacity(0.12)))
        /// Regular white button: B2 Decide Later, B3 Continue Drafting, B4 Reject.
        static let button = Elevation(ring: .ink(0.15), drop: Drop(y: 1, blur: 2, color: .black.opacity(0.08)))
        /// Small white button: A3 Change…, Add Rule, Edit Files.
        static let buttonSmall = Elevation(ring: .ink(0.12), drop: Drop(y: 1, blur: 2, color: .black.opacity(0.06)))
        /// B1 small white button (26 pt).
        static let buttonSmallLight = Elevation(ring: .ink(0.12), drop: Drop(y: 1, blur: 2, color: .black.opacity(0.05)))
        /// Toolbar white button: B6 Hand Off Anyway, C1 Undo Change.
        static let buttonToolbar = Elevation(ring: .ink(0.12), drop: Drop(y: 1, blur: 3, color: .black.opacity(0.08)))
        /// Toolbar white control: B4/B5 (32 pt).
        static let toolbarControl = Elevation(ring: .ink(0.18), drop: Drop(y: 1, blur: 3, color: .black.opacity(0.06)))
        /// Toolbar glass group (B1–B5). macOS 26 draws toolbar glass; reference value.
        static let toolbarGroup = Elevation(ring: .ink(0.1), drop: Drop(y: 1, blur: 4, color: .black.opacity(0.08)))
        /// Sidebar panel (B2–C3).
        static let sidebar = Elevation(ring: .ink(0.08), drop: Drop(y: 1, blur: 3, color: .black.opacity(0.05)))
        /// Selected segment: A3 mode control, B4 inspector tab.
        static let segmentSelected = Elevation(ring: .ink(0.06), drop: Drop(y: 1, blur: 2, color: .black.opacity(0.1)))
        /// B2 option radio, off.
        static let radioOff = Elevation(ring: .ink(0.3), drop: Drop(y: 1, blur: 1, color: .black.opacity(0.06)))
        /// B2 option radio, on.
        static let radioOn = Elevation(ring: .ink(0.1))
        /// B2 option key ("1", "2" …).
        static let optionKey = Elevation(ring: .ink(0.12))
        /// C4 pop-up menu.
        static let menu = Elevation(ring: .ink(0.15))
        /// Switch knob (B1, B7, C4).
        static let switchKnob = Elevation(drop: Drop(y: 1, blur: 2, color: .black.opacity(0.25)))
        /// B2 note field: ring plus inner shadow.
        static let field = Elevation(ring: .ink(0.22), innerDrop: Drop(y: 0.5, blur: 1, color: .black.opacity(0.06)))

        // Inset outlines
        /// A1 agent list, B1 form box, toolbar status pill.
        static let outlineFaint = Elevation(ring: .ink(0.06), insetRing: true)
        /// B1 unselected size card, A4x unselected card, B5 box, C4 switch track.
        static let outlineLight = Elevation(ring: .ink(0.08), insetRing: true)
        /// B5 attachment tiles, A1x install command.
        static let outline = Elevation(ring: .ink(0.1), insetRing: true)
        /// C1 replaced decision (shown at 0.6 opacity).
        static let outlineReplaced = Elevation(ring: .ink(0.12), insetRing: true)
        /// B5 and B6 cards.
        static let outlineCard = Elevation(ring: .ink(0.14), insetRing: true)
        /// A3 file list, B6 issue list, B7 task list.
        static let outlineList = Elevation(ring: .ink(0.16), insetRing: true)
        /// B4 box with an outline.
        static let outlineStrong = Elevation(ring: .ink(0.18), insetRing: true)
        /// B2 "Suggested" tag.
        static let outlineTag = Elevation(ring: .ink(0.25), insetRing: true)
        /// Selected chip, size card or drop zone (B1, A2, A4x).
        static let selected = Elevation(ring: Colors.accent, ringWidth: 1.5, insetRing: true)
        /// A2 empty drop zone.
        static let dropZone = Elevation(ring: .ink(0.14), ringWidth: 1.5, insetRing: true)
        /// B4 suggestion box, C1 new decision.
        static let accentBox = Elevation(ring: Colors.accentOutline, insetRing: true)
        /// C1 banner.
        static let banner = Elevation(ring: Colors.bannerOutline, insetRing: true)
        /// B5 "Missing" badge.
        static let missingBadge = Elevation(ring: Colors.caution, ringWidth: 1, insetRing: true)
    }

    /// Glow under the honeycomb logo (`filter: drop-shadow`).
    enum LogoShadow {
        /// A1 Welcome, 96 pt logo.
        static let large = Drop(y: 10, blur: 18, color: Color(red: 150 / 255, green: 90 / 255, blue: 0, opacity: 0.22))
        /// A1 second layer and B1, 32 pt logo.
        static let small = Drop(y: 3, blur: 6, color: Color(red: 150 / 255, green: 90 / 255, blue: 0, opacity: 0.18))
    }
}

// MARK: - V2 board (design/v2/V2-2-Board.dc.html and its states V2-4, 5, 7, 8, 9)

extension Theme.Colors {
    /// #B8000F · "These disagree" label, Remove… in a story's menu.
    static let disagreeText = Color(hex: 0xB8000F, dark: 0xFF7B72)
    /// rgba(215,0,21,0.45) · ring of an open "These disagree" card.
    static let disagreeRing = Color(hex: 0xD70015, opacity: 0.45, dark: 0xFF453A, darkOpacity: 0.6)
    /// #0058B9 · "Likely" on the suggested intake option.
    static let likely = Color(hex: 0x0058B9, dark: 0x6CB8FF)
    /// #6B2F00 · title of the stopped and unplaced banners.
    static let bannerTitle = Color(hex: 0x6B2F00, dark: 0xFFC98A)
    /// rgba(0,122,255,0.35) · ring of the edit banner; the button stub in a Screens node.
    static let accentRing = Color(hex: 0x007AFF, opacity: 0.35, dark: 0x0A84FF, darkOpacity: 0.595)
    /// rgba(0,122,255,0.5) · 1 pt ring of a focused text area (free answer, file editor).
    static let focusRing = Color(hex: 0x007AFF, opacity: 0.5, dark: 0x0A84FF, darkOpacity: 0.6)
    /// rgba(0,122,255,0.1) · a passage the last change touched; rgba(0,122,255,0.12) · Files button while open.
    static let changedFill = Color(hex: 0x007AFF, opacity: 0.1, dark: 0x0A84FF, darkOpacity: 0.17)
    static let filesOpenFill = Color(hex: 0x007AFF, opacity: 0.12, dark: 0x0A84FF, darkOpacity: 0.204)
    /// rgba(36,138,61,0.08) fill and rgba(36,138,61,0.3) ring of the change result line.
    static let resultFill = Color(hex: 0x248A3D, opacity: 0.08, dark: 0x30D158, darkOpacity: 0.136)
    static let resultRing = Color(hex: 0x248A3D, opacity: 0.3, dark: 0x30D158, darkOpacity: 0.51)
    /// rgba(0,0,0,0.07) · skeleton lines before the plan exists, bars in a Screens node; rgba(0,0,0,0.12) · its title bar.
    static let skeleton = Color.ink(0.07)
    static let skeletonStrong = Color.ink(0.12)
    /// rgba(0,0,0,0.1) · token button while its popover is open.
    static let pressedFill = Color.ink(0.1)
    /// rgba(245,245,247,0.86) · V2 sidebar panel; #FBE1AE / #8A4B00 · the project's letter tile.
    static let sidebarGlass = Color(hex: 0xF5F5F7, opacity: 0.86, dark: 0x2A2A2C, darkOpacity: 0.86)
    static let projectTile = Color(hex: 0xFBE1AE, dark: 0x5C4418)
    static let projectTileText = Color(hex: 0x8A4B00, dark: 0xFBD890)
}

extension Theme.Text {
    /// 15/20 bold · "Mel needs you", First version / Later, a file's `##` headings.
    static let boardTitle = Theme.TextStyle(size: 15, weight: .bold, lineHeight: 20)
    /// 22/28 bold · a file's `#` title in the board's reader.
    static let fileTitle = Theme.TextStyle(size: 22, weight: .bold, lineHeight: 28)
    /// 14/19 semibold · story title.
    static let storyTitle = Theme.TextStyle(size: 14, weight: .semibold, lineHeight: 19)
    /// 12/16 bold · Build order column title.
    static let calloutHeavy = Theme.TextStyle(size: 12, weight: .bold, lineHeight: 16)
    /// 13/18 bold · a Flow or Roadmap section's name; 11/14 bold · its number.
    static let planSectionTitle = Theme.TextStyle(size: 13, weight: .bold, lineHeight: 18)
    static let sectionNumber = Theme.TextStyle(size: 11, weight: .bold, lineHeight: 14)
    /// 13/17 semibold · project name in the V2 sidebar.
    static let sidebarProject = Theme.TextStyle(size: 13, weight: .semibold, lineHeight: 17)
    /// 12/16 bold on the tile · the project's letter.
    static let tileLetter = Theme.TextStyle(size: 12, weight: .bold, lineHeight: 16)
}

extension Theme.Size {
    /// 340 · "Mel needs you" column (drawn 300; widened so answers fit on a line or two).
    static let inboxWidth: CGFloat = 340
    /// 760 / 780 / 680 / 860 · widest Plan, open file and Tell Mel, intake summary, Flow and Roadmap.
    static let planMaxWidth: CGFloat = 760
    static let fileMaxWidth: CGFloat = 780
    static let askingMaxWidth: CGFloat = 680
    static let planTabMaxWidth: CGFloat = 860
    /// 40 · intake option row; 20 · its key box.
    static let optionRow: CGFloat = 40
    static let optionKey: CGFloat = 20
    /// 7 · file state dot in Files and the open file's header.
    static let fileDot: CGFloat = 7
    /// 8 × 14 · a story's drag grip, six 2.4 pt dots.
    static let gripWidth: CGFloat = 8
    static let gripHeight: CGFloat = 14
    static let gripDot: CGFloat = 2.4
    /// 2.8 · a dot of the ··· button, 5 pt apart.
    static let moreDot: CGFloat = 2.8
    /// 168 · a Flow screen card; 22 · Roadmap's indent under a task's number (criterion IDs use `criterionID`); 18 · a task's priority.
    static let flowNode: CGFloat = 168
    static let roadmapIndent: CGFloat = 22
    static let priorityChip: CGFloat = 18
    /// 12 and 56 · skeleton line and card before the plan exists.
    static let skeletonLine: CGFloat = 12
    static let skeletonCard: CGFloat = 56
    /// 190 · a story menu's least width; 26 · token popover row.
    static let tokenRow: CGFloat = 26
    /// 272 · V2 sidebar (drawn 244; widened for longer spec names); 26 · project tile; 40 · spec row; 44 · project button.
    static let boardSidebar: CGFloat = 272
    static let projectTile: CGFloat = 26
    static let specRow: CGFloat = 40
    static let projectButton: CGFloat = 44
    /// 16 lines · the file editor; 2 · Tell Mel and a card's free answer; 3 · an intake free answer.
    static let editorLines = 16
    static let tellLines = 2
    /// 640 × 440 · Tell Mel's larger editor; 11 · its expand glyph.
    static let tellSheetWidth: CGFloat = 640
    static let tellSheetHeight: CGFloat = 440
    static let expandIcon: CGFloat = 11
}

extension Theme.Elevation {
    /// Open decision card and the intake question card: ring 0.1 + 0 2 6 0.06.
    static let inboxCard = Theme.Elevation(ring: .ink(0.1), drop: Theme.Drop(y: 2, blur: 6, color: .black.opacity(0.06)))
    /// Open "These disagree" card: 1 pt red inset ring + 0 2 6 0.06.
    static let disagreeCard = Theme.Elevation(ring: Theme.Colors.disagreeRing, ringWidth: 1, insetRing: true, drop: Theme.Drop(y: 2, blur: 6, color: .black.opacity(0.06)))
    /// First-version story card and the Tell Mel box: ring 0.12 + 0 1 3 0.06.
    static let storyCard = Theme.Elevation(ring: .ink(0.12), drop: Theme.Drop(y: 1, blur: 3, color: .black.opacity(0.06)))
    /// A card's answer pill: ring 0.15 + 0 1 2 0.06.
    static let answerPill = Theme.Elevation(ring: .ink(0.15), drop: Theme.Drop(y: 1, blur: 2, color: .black.opacity(0.06)))
    /// White pill without a shadow (banner buttons, First, Restore, Cancel): ring 0.15; "Something else…": the same ring, inset.
    static let pill = Theme.Elevation(ring: .ink(0.15))
    static let pillOutline = Theme.Elevation(ring: .ink(0.15), insetRing: true)
    /// Edit in an open file: ring 0.18.
    static let editButton = Theme.Elevation(ring: .ink(0.18))
    /// A file chip in Files: ring 0.1; the open file's article and a Build order task: ring 0.12 / 0.1.
    static let fileChip = Theme.Elevation(ring: .ink(0.1))
    static let article = Theme.Elevation(ring: .ink(0.12))
    /// Token popover and a story's menu: ring 0.12 + 0 8 24 0.14.
    static let popover = Theme.Elevation(ring: .ink(0.12), drop: Theme.Drop(y: 8, blur: 24, color: .black.opacity(0.14)))
    /// A Flow branch target and a section's number: ring 0.12.
    static let flowChip = Theme.Elevation(ring: .ink(0.12))
    /// Flow screen card: ring 0.12 + 0 1 2 0.05.
    static let flowNode = Theme.Elevation(ring: .ink(0.12), drop: Theme.Drop(y: 1, blur: 2, color: .black.opacity(0.05)))
    /// Focused text area: 1 pt inset accent ring.
    static let focus = Theme.Elevation(ring: Theme.Colors.focusRing, ringWidth: 1, insetRing: true)
    /// Edit banner and change result: inset rings in their own color.
    static let editBanner = Theme.Elevation(ring: Theme.Colors.accentRing, insetRing: true)
    static let result = Theme.Elevation(ring: Theme.Colors.resultRing, insetRing: true)
    /// V2 sidebar's project button and New: ring 0.12 + 0 1 2 0.06.
    static let sidebarButton = Theme.Elevation(ring: .ink(0.12), drop: Theme.Drop(y: 1, blur: 2, color: .black.opacity(0.06)))
}

// MARK: - V2 screens (design/v2/V2-0-Start, V2-1-New, V2-3-Ready, V2-6-Settings-Specs and the V2 sidebar)

extension Theme.Colors {
    /// #1D1D1F · the agent's dark tile with the white terminal glyph (Settings › Agents); a shade lighter on Dark.
    static let agentTile = Color(hex: 0x1D1D1F, dark: 0x3A3A3C)
    /// #FFFFFF · the selected segment of a pill-shaped picker; on Dark it must be lighter than its track, not the window's color.
    static let segmentFill = Color(hex: 0xFFFFFF, dark: 0x48484A)
    /// #8E8E93 · an empty sidebar group ("Nothing waiting for you").
    static let emptyGroup = Color(hex: 0x8E8E93, dark: 0x7C7C80)
    /// rgba(0,122,255,0.1) · the sidebar's New button while New is open; its text is `likely` (#0058B9).
    static let newActiveFill = Color(hex: 0x007AFF, opacity: 0.1, dark: 0x0A84FF, darkOpacity: 0.17)
    /// rgba(0,122,255,0.35) · glow under "Build with Claude Code".
    static let buildGlow = Color(hex: 0x007AFF, opacity: 0.35, dark: 0x0A84FF, darkOpacity: 0.595)
    /// rgba(0,122,255,0.3) · 3 pt halo of the focused idea box on New.
    static let focusHalo = Color(hex: 0x007AFF, opacity: 0.3, dark: 0x0A84FF, darkOpacity: 0.51)
    /// #ECECEC · Settings › Specs window content.
    static let settingsBackground = Color(hex: 0xECECEC, dark: 0x242426)
    /// rgba(0,0,0,0.14) · switch track off in Settings › Specs.
    static let settingsSwitchOff = Color.ink(0.14)
}

extension Theme.Text {
    /// 14/20 · New's line under the title.
    static let introTight = Theme.TextStyle(size: 14, weight: .regular, lineHeight: 20)
    /// 15/20 semibold · "Build with Claude Code".
    static let buildButton = Theme.TextStyle(size: 15, weight: .semibold, lineHeight: 20)
}

extension Theme.Size {
    /// Start: column 620 with 40 pt sides, 56 pt logo, text max 440, bar 40; project rows min 48 with a 16 pt radio
    /// (5 pt ring when on); agent chips 24; install rows with a 92 pt name.
    static let startWidth: CGFloat = 620
    static let startLogo: CGFloat = 56
    static let startTextWidth: CGFloat = 440
    static let startBar: CGFloat = 40
    static let startRow: CGFloat = 48
    static let startRadio: CGFloat = 16
    static let startRadioRing: CGFloat = 5
    static let installName: CGFloat = 92
    /// New: column 680; idea box of 5 lines with a 52 pt bottom row; 32 pt attach button with a 15 pt clip.
    static let newWidth: CGFloat = 680
    static let newIdeaLines = 5
    static let newBoxFooter: CGFloat = 52
    static let attachButton: CGFloat = 32
    static let attachIcon: CGFloat = 15
    /// V2 sidebar: the system column already starts below the traffic lights, so no extra top; file rows 24; New 30; agent line 22.
    static let sidebarTop: CGFloat = 0
    static let sidebarFileRow: CGFloat = 24
    static let sidebarNew: CGFloat = 30
    static let sidebarAgentLine: CGFloat = 22
    static let buildButton: CGFloat = 44
    /// Settings › Specs: rows min 52; a rule's remove button 20. Every pane is `settingsWidth` wide, so switching panes only changes the height.
    static let specsSettingsRow: CGFloat = 52
    static let ruleRemove: CGFloat = 20
}

extension Theme.Elevation {
    /// New's idea box: ring 0.16 + 0 2 10 0.06; focused: 0.5 pt accent ring (its 3 pt halo is drawn apart).
    static let ideaBox = Theme.Elevation(ring: .ink(0.16), drop: Theme.Drop(y: 2, blur: 10, color: .black.opacity(0.06)))
    static let ideaBoxFocused = Theme.Elevation(ring: Theme.Colors.accent, drop: Theme.Drop(y: 2, blur: 10, color: .black.opacity(0.06)))
    /// New's size chip: 1 pt inset accent ring at 0.35.
    static let sizeChip = Theme.Elevation(ring: Theme.Colors.accentRing, ringWidth: 1, insetRing: true)
    /// Start's radio, off: 1 pt inset ring at 0.3.
    static let startRadioOff = Theme.Elevation(ring: .ink(0.3), ringWidth: 1, insetRing: true)
    /// "Build with Claude Code": 0 1 3 accent glow.
    static let buildButton = Theme.Elevation(drop: Theme.Drop(y: 1, blur: 3, color: Theme.Colors.buildGlow))
    /// Ready's disclosure box: inset ring 0.12.
    static let disclosure = Theme.Elevation(ring: .ink(0.12), insetRing: true)
    /// Settings › Specs: a value pop-up (ring 0.18 + 0 1 1 0.06) and a small button (ring 0.18).
    static let settingsValue = Theme.Elevation(ring: .ink(0.18), drop: Theme.Drop(y: 1, blur: 1, color: .black.opacity(0.06)))
    static let settingsButton = Theme.Elevation(ring: .ink(0.18))
}

// MARK: - V2-3 Build (design/v2/V2-3-Ready.dc.html)

extension Theme.Colors {
    /// rgba(215,0,21,0.05) · a failed check's output box.
    static let failedFill = Color(hex: 0xD70015, opacity: 0.05, dark: 0xFF453A, darkOpacity: 0.085)
    /// rgba(215,0,21,0.3) · its inset ring.
    static let failedRing = Color(hex: 0xD70015, opacity: 0.3, dark: 0xFF453A, darkOpacity: 0.51)
}

extension Theme.Text {
    /// 14/19 bold · "Step 1".
    static let stepTitle = Theme.TextStyle(size: 14, weight: .bold, lineHeight: 19)
    /// 11/16 · the aside's closing line.
    static let captionTall = Theme.TextStyle(size: 11, weight: .regular, lineHeight: 16)
    /// 11/16 mono · Show prompt.
    static let codePrompt = Theme.TextStyle(size: 11, weight: .regular, lineHeight: 16, design: .monospaced)
}

extension Theme.Size {
    /// The steps column's max width.
    static let buildWidth: CGFloat = 820
    /// "How building works" and Tell Mel on Build (drawn 280; as wide as the board's inbox so a request has room).
    static let buildAside: CGFloat = 340
    /// A task running in Mel shows its last 5 steps until "All steps".
    static let runLines = 5
    /// A task card's basis in an "At the same time" step.
    static let taskCardMin: CGFloat = 260
    /// The progress bar's segments.
    static let segment: CGFloat = 6
    static let stepBadge: CGFloat = 20
    static let terminalButton: CGFloat = 30
    static let terminalButtonIcon: CGFloat = 13
    static let doneCheck: CGFloat = 12
    static let promptChevron: CGFloat = 8
    static let howNumber: CGFloat = 20
    /// "New" on a task Tell Mel added (V2-13).
    static let newTag: CGFloat = 18
    /// Tell Mel's text field in the right panel.
    static let buildTellLines = 4
}

extension Theme.Radius {
    /// A step's grey box.
    static let step: CGFloat = 14
}

extension Theme.Elevation {
    /// A waiting task: inset 0.5 pt ring, no drop.
    static let taskWaiting = Theme.Elevation(ring: .ink(0.12), insetRing: true)
    /// A failed task: inset 1 pt red ring and a soft drop.
    static let taskFailed = Theme.Elevation(ring: Theme.Colors.disagreeRing, ringWidth: 1, insetRing: true, drop: Theme.Drop(y: 1, blur: 3, color: .black.opacity(0.06)))
    static let failedOutput = Theme.Elevation(ring: Theme.Colors.failedRing, insetRing: true)
    /// A task the last Tell Mel change added (V2-13): `accentTint` with an inset 1 pt ring at 0.35.
    static let taskNew = Theme.Elevation(ring: Theme.Colors.accentRing, ringWidth: 1, insetRing: true)
}

// MARK: - GitHub (design/v2/GH-1 to GH-5)

extension Theme.Colors {
    /// rgba(36,138,61,0.12) / #1A7F37 · an open pull request's chip.
    static let openChipFill = Color(hex: 0x248A3D, opacity: 0.12, dark: 0x30D158, darkOpacity: 0.2)
    static let openChipText = Color(hex: 0x1A7F37, dark: 0x30D158)
    /// rgba(130,80,223,0.12) / #6E40C9 · a merged pull request's chip.
    static let mergedChipFill = Color(hex: 0x8250DF, opacity: 0.12, dark: 0xA371F7, darkOpacity: 0.22)
    static let mergedChipText = Color(hex: 0x6E40C9, dark: 0xBC8CFF)
}

extension Theme.Text {
    /// 10/12 · "Not on this Mac" on a repo row.
    static let repoTag = Theme.TextStyle(size: 10, weight: .regular, lineHeight: 12)
    /// 17/22 semibold mono · the one-time code on GitHub sign-in.
    static let deviceCode = Theme.TextStyle(size: 17, weight: .semibold, lineHeight: 22, design: .monospaced)
}

extension Theme.Size {
    /// Start: the 76 pt label column of the agent and GitHub lines; a repo row's 16 pt tag.
    static let startLineLabel: CGFloat = 76
    static let repoTag: CGFloat = 16
    /// GH-2 / GH-3: the sheet's width; the repo list's rows.
    static let repoSheet: CGFloat = 520
    static let repoListRow: CGFloat = 32
    /// GH-4: the pull request's Open / Merged chip.
    static let prChip: CGFloat = 20
}

// MARK: - Motion

extension Animation {
    /// Things that appear, leave or change place on the board, in the sidebar and between screens.
    static let board = Animation.smooth(duration: 0.28)
}

extension AnyTransition {
    /// A banner or card coming in from above its place.
    static let drop = AnyTransition.opacity.combined(with: .offset(y: -6))
}

extension View {
    /// Font, tracking and exact line height of a design text style, glyphs placed like CSS.
    func textStyle(_ style: Theme.TextStyle) -> some View {
        font(style.font)
            .tracking(style.tracking)
            .lineHeight(style.lineHeight.map { .exact(points: $0) })
            .offset(y: style.glyphShift)
    }

    /// Background of a box: fill, hairline ring and shadow (CSS `background` + `box-shadow`). Shadows assume an opaque fill.
    func surface(_ fill: Color, _ elevation: Theme.Elevation = .init(), in shape: some InsettableShape) -> some View {
        background {
            if let drop = elevation.drop {
                shape.fill(fill.shadow(.drop(color: drop.color, radius: drop.radius, y: drop.y)))
            } else if let drop = elevation.innerDrop {
                shape.fill(fill.shadow(.inner(color: drop.color, radius: drop.radius, y: drop.y)))
            } else {
                shape.fill(fill)
            }
        }
        .overlay {
            if let ring = elevation.ring {
                if elevation.insetRing {
                    shape.strokeBorder(ring, lineWidth: elevation.ringWidth)
                } else {
                    shape.inset(by: -elevation.ringWidth / 2).stroke(ring, lineWidth: elevation.ringWidth)
                }
            }
        }
    }

    /// A design shadow on any view (the logo glow).
    func shadow(_ drop: Theme.Drop) -> some View {
        shadow(color: drop.color, radius: drop.radius, y: drop.y)
    }
}

extension Color {
    /// A design color: sRGB `0xRRGGBB` as drawn for Light, and its Dark counterpart. The design draws
    /// Light only; the Dark values are Mel's own, on macOS's dark palette (OQ #21). SwiftUI has no
    /// initializer for a light/dark pair, so this is the one place a view file uses AppKit.
    fileprivate init(hex: UInt32, opacity: Double = 1, dark: UInt32, darkOpacity: Double? = nil) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : hex, opacity: isDark ? darkOpacity ?? opacity : opacity)
        })
    }

    /// A neutral wash or hairline: black at `opacity` on Light, white a little stronger on Dark,
    /// where the same opacity reads weaker.
    static func ink(_ opacity: Double) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(white: 1, alpha: min(opacity * 1.4 + 0.02, 1))
                : NSColor(white: 0, alpha: opacity)
        })
    }
}

private extension NSColor {
    convenience init(hex: UInt32, opacity: Double) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: opacity
        )
    }
}

#Preview("Text") {
    VStack(alignment: .leading, spacing: Theme.Space.x8) {
        Text("Welcome to Mel").textStyle(Theme.Text.largeTitle)
        Text("Requirements").textStyle(Theme.Text.title2)
        Text("1. Book a class").textStyle(Theme.Text.headline)
        Text("REQUIREMENTS.md").textStyle(Theme.Text.toolbarTitle)
        Text("As a member, I want to book a class from the schedule.").textStyle(Theme.Text.prose)
        Text("Before you approve").textStyle(Theme.Text.bodyBold)
        Text("Saved · your edits are never overwritten").textStyle(Theme.Text.caption)
            .foregroundStyle(Theme.Colors.secondaryLabel)
        Text("1.1").textStyle(Theme.Text.codeProse).foregroundStyle(Theme.Colors.secondaryLabel)
    }
    .foregroundStyle(Theme.Colors.label)
    .padding(Theme.Space.x32)
    .background(Theme.Colors.background)
}

#Preview("Surfaces") {
    VStack(spacing: Theme.Space.x16) {
        Text("Approve").textStyle(Theme.Text.bodyBold).foregroundStyle(Theme.Colors.onAccent)
            .padding(.horizontal, Theme.Space.x16).frame(height: Theme.Size.buttonToolbar)
            .surface(Theme.Colors.accent, .primaryToolbar, in: Capsule())
        Text("Decide Later").textStyle(Theme.Text.body)
            .padding(.horizontal, Theme.Space.x16).frame(height: Theme.Size.button)
            .surface(Theme.Colors.background, .button, in: Capsule())
        Text("P1 · MVP").textStyle(Theme.Text.captionBold)
            .padding(.horizontal, Theme.Space.x7).frame(height: Theme.Size.badge)
            .surface(Theme.Colors.badgeFill, in: Capsule())
        Text("Missing").textStyle(Theme.Text.captionBold).foregroundStyle(Theme.Colors.cautionText)
            .padding(.horizontal, Theme.Space.x8).frame(height: Theme.Size.badge)
            .surface(Theme.Colors.background, .missingBadge, in: Capsule())
        Text("Before you approve").textStyle(Theme.Text.bodyBold)
            .frame(maxWidth: .infinity, alignment: .leading).padding(Theme.Space.x12)
            .surface(Theme.Colors.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.box))
    }
    .foregroundStyle(Theme.Colors.label)
    .padding(Theme.Space.x32)
    .frame(width: 360)
    .background(Theme.Colors.background)
}
