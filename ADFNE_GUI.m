classdef ADFNE_GUI < handle
%ADFNE_GUI  Graphical workbench for ADFNE (Alghalandis Discrete Fracture
%           Network Engineering).
%
%   ADFNE_GUI              launches the app, auto-detecting the ADFNE folder
%   ADFNE_GUI(adfneRoot)   launches the app against a specific ADFNE folder
%
%   The app is self-contained: everything it needs sits inside this folder.
%
%     ADFNE_GUI.m     the whole app, one file
%     lib\adfne\      merged ADFNE library, 1.5 and 1.0 side by side
%                     (1.5 verbatim; 1.0 colliding names suffixed _R1)
%     lib\deps\       dependency layer for what ADFNE does not ship
%     docs\           licences and the ADFNE 1.5 handbook
%     examples\       ADFNE 1.0 example scripts
%     exports\        default output folder
%
%   Paths are set up at launch and point only inside this folder. Generation
%   and flow run on ADFNE 1.5 (DFN, Pipe/Backbone/Graph/Solve); the intensity,
%   connectivity-field and borehole analyses that 1.5 dropped come from 1.0.
%
%   Tabs -- each one a question about the rock mass
%     Model         domain, section plane, joint sets, generation
%     Conditioning  where field data enters: fit the joint sets to a mapped
%                   face, and make the model reproduce its traces exactly
%     Analysis      clustering, backbone, fields, intensity, pipe model, ...
%     Flow          pipe-graph solver: pressure, flux, effective conductivity
%
%   The viewport owns everything about the picture: view, plot type and colour
%   above it, a collapsible Display dock of styling below it, and the render
%   and image actions in the row under that. Plots was a tab until it became
%   clear it was chrome for a viewport already on screen.
%
%   Export… in the header opens its own window: PNG/PDF/SVG/FIG/VTK/HTML/
%   MAT/CSV. Console opens a separate searchable browser over all ADFNE
%   functions. It lists every .m file, shows its help, generates a call
%   template from the signature, and evaluates it against a live variable
%   store.
%
%   Author: built for the ADFNE workbench. Requires MATLAB R2020b or newer.

    properties (Constant, Access = private)
        VERSION   = '2.0'
        ACCENT    = [0.086 0.325 0.560]
        ACCENT_LT = [0.918 0.945 0.973]
        BG        = [0.960 0.965 0.972]
        PANEL     = [1.000 1.000 1.000]
        % The help window wears the same layout in a warmer skin, so there is
        % never a doubt which window you are in: a click here explains, a
        % click there builds. Same hues, warmed, so the accent and the three
        % register tints - which carry meaning - still read against it.
        HELP_BG    = [0.949 0.910 0.831]
        HELP_PANEL = [0.996 0.982 0.949]
        HELP_BAR   = [0.902 0.847 0.745]
        OK_COL    = [0.106 0.451 0.243]
        ERR_COL   = [0.694 0.145 0.145]
        WARN_COL  = [0.706 0.451 0.075]
        % The three registers. Every group of controls that could be mistaken
        % for another kind belongs to exactly one of these, and they never
        % share a colour. GENERATIVE controls are what GENERATE builds from,
        % so changing one marks the model out of date. VIEWING controls only
        % change how you look at it and can never make it stale. FACE controls
        % are measured in 2D on a mapped face and are not the rock mass at all.
        %
        % This exists because two tables in this app are both grey numeric
        % grids -- joint sets, which are 3D fractures, and trace statistics,
        % which are 2D lines on one face -- and telling them apart mattered
        % enough that the code comment above CondStatsLbl records the
        % confusion. Analysis and Flow parameters carry no register: they
        % measure the model rather than defining, viewing, or mapping it.
        % One input row is a label and its field, and every panel in the app
        % builds from the same two numbers. Panels are then sized to their
        % contents -- title + padding + n rows -- rather than given '1x' and
        % left to swell. Only ONE thing per tab should hold '1x', and it
        % should be the thing worth growing: the joint-set table, the analysis
        % results, the trace map. A panel of fixed controls given '1x' just
        % spreads its own whitespace.
        ROW_H     = 22
        FLD_W     = 108   % the widest thing that goes in one: 'legacy quad', 105 px
        REG_GEN   = [0.086 0.325 0.560]
        REG_VIEW  = [0.420 0.306 0.620]
        REG_FACE  = [0.647 0.404 0.055]
    end

    properties (Access = public)
        Fig
        AdfneRoot char = ''
        HasR15    logical = false
        DepsRoot  char = ''
        Model     struct = struct()
        Sets      double = []             % joint sets, canonical columns (9: ... Lmin Lmean Lmax Lp)
        SizeLawDD                         % which size distribution the sizes are drawn from
        AspectField, AspectSdField, AxisDD % elongated polygons: aspect ratio, its spread, long axis
        AspectLawDD                       % which law the elongation (aspect - 1) follows
        IntensityDD                       % column 1 of the table: a count, or a P32
        OrientDD                          % orientation model: ADFNE's two angles, one Fisher pole, or the mapped poles
        LastOrient char = 'adfne'         % the model the scatter columns are currently written in
        LastIntensity char = 'N'          % what column 1 is currently written as
        CentresDD, ClusterField           % where centres go: uniform, nearest neighbour, Levy-Lee; its parameter
        TermField                         % Enhanced Baecher: percent of intersecting fractures cut back
        P32Ratio                          % cache: P32 per fracture, keyed on the set's parameters
        TraceSets double = []             % 2D statistics for a synthetic map: N Dir Kappa Lmin Lmean Lmax Lp
        TraceMap  double = []             % the map itself: [u1 v1 u2 v2] rows
        TraceSid  double = []             % joint set each mapped trace belongs to
        PlaneSets double = []             % 3D statistics for synthetic planes in the band
        PlanesLocal cell = {}             % mapped joint planes, local frame (origin = band centre)
        PlanesSid double = []             % joint set per mapped plane, [] if the file had none
        PlanesFileName char = ''          % the planes file, whether or not in use
        PlanesFmt char = ''               % which layout it was read as
        BandThkF                          % thickness of the 3D band
        BandCutCB                         % the mapped planes are every plane that CUTS the band (a scan)
        BandClipCB                        % ... and are CLIPPED at the band faces (censored sizes)
        Vars      struct = struct()
        FcnNames  cell   = {}
        FcnFiles  cell   = {}
    end

    properties (Access = public, Hidden = true)
        % layout
        Ax
        PlotHost
        PlotGrid
        RootGrid
        StateBar
        StateFactsLbl
        LogArea
        LogGrid
        LogSummary
        LogToggleBtn
        LogExpanded logical = false
        LogErrorActive logical = false
        LastLogLine char = ''
        StatusLbl
        PathLbl
        TabGroup
        % model tab
        ModeDD, RgnFields, SetTable, SeedSpin, RandSeedCB, FacetSpin
        SecDipF, SecDirF, SecOffF, SecClipDD, PresetDD, SecShowCB
        PrevPlot char = ''
        PrevPlotTM char = ''        % what to restore when the trace map is dismissed
        LastRenderError char = ''   % '' after a clean render; see renderPlot
        BusyDepth double = 0        % only the outermost operation shows a dialog
        OpTimes struct = struct()    % how long each kind of work took last time
        % conditioning tab
        CondCB, CondSrcDD, CondTable, CondSetDD, CondExclCB, CondFileLbl
        CondInfo, CondPreviewBtn, FitTable, FitLbl, CondInheritLbl, CondStatsLbl
        CondCompareBtn, CondRestoreBtn, FitBtn, CondSrcPanel
        Baseline struct = struct()  % the DFN before fitting or conditioning
        FitApplied logical = false  % a fit is in effect; do not move the baseline
        QuietGuards logical = false % tests: guides log instead of opening a dialog
        CondFileName char = ''      % last imported file, whether or not in use
        ShapeDD, ASepField, DSepField
        GenBtn, SetHintLbl
        % analysis tab
        AnaList, AnaRunBtn, ResTable
        AnaGrid                     % the tab's own grid, so the panel can size its row
        AnaParamPanel, AnaParamGrid, AnaParamHint
        AnaGridRow, AnaSliceRow, AnaBhRow   % disclosed with the analyses that read them
        % flow tab
        FlowDirDD, FlowBCDD, FlowMtdDD, FlowPinF, FlowPoutF, FlowApF, FlowKvF
        FlowRunBtn, FlowInfo
        GridSpin, PlaneDD, PlaneVal
        BhX1,BhY1,BhZ1,BhX2,BhY2,BhZ2,BhR
        % plot selection (viewport row) and styling (viewport dock)
        PlotDD, ColorDD, AlphaSld, LWSpin, CmapDD
        BoxCB, GridCB, CbarCB, LightCB, AutoCB, Show3DCB
        AzSld, ElSld
        ViewGrid                    % the viewport column, so the dock can size its row
        DockGrid, DockBody, DockToggleBtn
        DockExpanded logical = false
        RenderBtn                   % lives with the viewport actions, never in the dock
        % export dialog
        OutDirField, BaseNameField, FmtList
        ExportFig                   % built hidden at startup: onSaveSession reads OutDirField
        % functions tab
        SearchField, FcnList, HelpArea, ConsoleArea, OutArea, VarTable
        ToolTree, AllFcnCB, ConsoleFig
        % help mode: the same window, where every click explains instead of acts
        HelpMode logical = false
        HelpHtml                    % the explanation page, where the viewport was
        HelpApp                     % the help window a working window opened
        HelpNames = {}              % property name of every registered control ...
        HelpHandles = []            % ... and its handle, so a click can be named
        HelpBtn
    end

    %% ---------------------------------------------------------------- public
    methods (Access = public)
        function app = ADFNE_GUI(adfneRoot, mode)
            %ADFNE_GUI  The workbench. ADFNE_GUI('help') or ADFNE_GUI(root,
            %   'help') opens the same window in HELP MODE: every control is
            %   there and clickable, and clicking one explains it in the
            %   viewport instead of doing anything. The Help button opens it.
            helpArg = nargin >= 2 && strcmpi(mode, 'help');
            if nargin >= 1 && (ischar(adfneRoot) || isstring(adfneRoot)) && ...
                    strcmpi(adfneRoot, 'help') && ~isfolder(adfneRoot)
                helpArg = true; adfneRoot = '';
            end
            app.HelpMode = helpArg;
            % One workbench at a time. Re-running the file used to leave the
            % old window open beside the new one, and the two disagreed about
            % everything. Only when launched from the prompt, though: the
            % regression suite builds several instances at once on purpose,
            % and closing its own windows would take the suite down with them.
            st = dbstack;
            if numel(st) <= 1 && ~app.HelpMode, ADFNE_GUI.closeOpenWorkbenches(); end
            here = fileparts(mfilename('fullpath'));
            addpath(here);
            app.DepsRoot = fullfile(here, 'lib', 'deps');
            addpath(app.DepsRoot);
            if nargin < 1 || isempty(adfneRoot)
                adfneRoot = ADFNE_GUI.detectRoot();
                if isempty(adfneRoot)
                    adfneRoot = uigetdir(here, ...
                        'Locate the ADFNE folder (the one containing DFN.m)');
                    if isequal(adfneRoot, 0), adfneRoot = ''; end
                end
            end
            app.buildUI();
            app.attachRoot(adfneRoot);
            app.resetModel();
            if app.HelpMode
                app.enterHelpMode();
            else
                app.log(sprintf('ADFNE Workbench %s ready.', app.VERSION), 'ok');
            end
        end

        function delete(app)
            if ~isempty(app.HelpApp) && isvalid(app.HelpApp), delete(app.HelpApp); end
            if ~isempty(app.ConsoleFig) && isvalid(app.ConsoleFig)
                delete(app.ConsoleFig);
            end
            if ~isempty(app.ExportFig) && isvalid(app.ExportFig)
                delete(app.ExportFig);
            end
            if ~isempty(app.Fig) && isvalid(app.Fig), delete(app.Fig); end
        end
    end

    methods (Static, Access = public)
        function closeOpenWorkbenches()
            %CLOSEOPENWORKBENCHES  Shut every window a previous run left behind.
            %   Found by Tag, so the console, the export window and any compare
            %   figures go with the main one rather than being orphaned.
            old = findall(groot, 'Type', 'figure');
            for i = 1:numel(old)
                t = old(i).Tag;
                if (ischar(t) || isstring(t)) && startsWith(string(t), 'ADFNE_GUI')
                    delete(old(i));
                end
            end
        end

        function w = kindToWord(k)
            switch k
                case 2, w = "merged ADFNE 1.5 + 1.0";
                case 1, w = "ADFNE 1.0 only";
                otherwise, w = "not an ADFNE folder";
            end
        end

        function armGlobals(root)
            %ARMGLOBALS  Static twin of initR15Globals, for headless use.
            global Tolerance Colormap Segment Poly Precise Times Messages ...
                   Report Details Runtime Left History Labels Round Interval ...
                   Debug RandomColor Silent Line CMapLength %#ok<GVMIS>
            Tolerance = 1e-14;  Colormap = @jet;  Segment = 24;
            Poly = struct( ...
                'Left',  [0,0,0; 0,0,1; 0,1,1; 0,1,0], ...
                'Right', [1,0,0; 1,0,1; 1,1,1; 1,1,0], ...
                'Top',   [0,0,1; 1,0,1; 1,1,1; 0,1,1], ...
                'Bottom',[0,0,0; 1,0,0; 1,1,0; 0,1,0], ...
                'Front', [0,0,0; 1,0,0; 1,0,1; 0,0,1], ...
                'Back',  [0,1,0; 1,1,0; 1,1,1; 0,1,1]);
            Line = struct('Left',[0,0,0,1],'Right',[1,0,1,1], ...
                'Top',[0,1,1,1],'Bottom',[0,0,1,0], ...
                'CH',[0,0.5,1,0.5],'CV',[0.5,0,0.5,1]);
            Times = {};  Messages = {};  History = {};
            Report = false;  Details = false;  Runtime = 10;
            Left = repmat(' ',1,22);  Labels = false;  Interval = 0.1;
            Debug = false;  RandomColor = false;  Silent = true;
            Round = @(x)round(x,16);  Precise = @(x)x;  CMapLength = 256;
            % ADFNE 1.5 ships R2015a shims for contains/pad/setstructfields.
            % On a modern release those shadow the built-ins with different
            % semantics - the shim contains() returns a scalar for cellstr
            % input, which silently breaks the Library tab search - so the
            % folder goes on the path only when something is genuinely absent.
            r15 = fullfile(root,'R2015a');
            shims = {'contains','pad','setstructfields'};
            missing = shims(cellfun(@(f) exist(f) == 0, shims));            %#ok<EXIST>
            if exist(r15,'dir') && ~isempty(missing)
                addpath(r15);
            end
        end

        function root = detectRoot()
            % The app ships its own library and deliberately never looks
            % outside its own folder, so the whole thing can be copied to
            % another machine and still run.
            here = fileparts(mfilename('fullpath'));
            cand = { fullfile(here, 'lib', 'adfne'), ...
                     fullfile(here, 'lib', 'ADFNE'), ...
                     fullfile(here, 'adfne') };
            root = '';
            for i = 1:numel(cand)                       % merged tree wins
                if ADFNE_GUI.rootKind(cand{i}) == 2, root = cand{i}; return, end
            end
            for i = 1:numel(cand)                       % otherwise any 1.0 tree
                if ADFNE_GUI.rootKind(cand{i}) == 1, root = cand{i}; return, end
            end
        end

        function k = rootKind(root)
            %ROOTKIND  0 = not ADFNE, 1 = ADFNE 1.0 only, 2 = merged 1.5 + 1.0.
            k = 0;
            if isempty(root) || ~exist(root, 'dir'), return, end
            has10 = exist(fullfile(root, 'GenFNM2D.m'), 'file') == 2;
            has15 = exist(fullfile(root, 'DFN.m'), 'file') == 2 && ...
                    exist(fullfile(root, 'Option.m'), 'file') == 2;
            if has10 && has15, k = 2; elseif has10, k = 1; end
        end

        function ok = smoketest(adfneRoot)
            %SMOKETEST  headless check of the library behind the app.
            %   Covers ADFNE 1.0, and - when the merged library is in use - the
            %   1.5 generator plus the renamed 1.0 functions that would collide
            %   with it, since a bad merge shows up exactly there.
            if nargin < 1, adfneRoot = ADFNE_GUI.detectRoot(); end
            here = fileparts(mfilename('fullpath'));
            addpath(adfneRoot); addpath(fullfile(here,'lib','deps'));
            kind = ADFNE_GUI.rootKind(adfneRoot);
            fprintf('library: %s  (%s)\n', adfneRoot, ...
                string(ADFNE_GUI.kindToWord(kind)));
            checks = { ...
              '1.0 2D generation',   @() GenFNM2D(60,0,0,0.05,0.4); ...
              '1.0 2D clustering',   @() LinesToClusters2D(GenFNM2D(60)); ...
              '1.0 2D backbone',     @() Backbone2D(GenFNM2D(60), true); ...
              '1.0 2D density',      @() Density2D(GenFNM2D(60), 8, 8); ...
              '1.0 2D P21 grid',     @() P21G(GenFNM2D(60), 8, 8); ...
              '1.0 3D generation',   @() GenFNM3DE(30, pi/4, pi/4, pi, pi, 0.25); ...
              '1.0 3D intersections',@() PolysX3D(GenFNM3DE(25, pi/4, pi/4, pi, pi, 0.3)); ...
              '1.0 3D pipe model',   @() FNMPipes3D(GenFNM3DE(25, pi/4, pi/4, pi, pi, 0.3)); ...
              'geom3d transforms',   @() transformPoint3d([0 0 0; 1 1 1], createRotationOy([0 0 0], 0.3)); ...
              'plane intersection',  @() intersectEdgePlane([0 0 0 1 1 1], createPlane([0 0 .5],[0 0 1])); ...
              };
            if kind == 2
                ADFNE_GUI.armGlobals(adfneRoot);
                checks = [checks; { ...
                  '1.5 2D DFN',        @() DFN('dim',2,'n',40); ...
                  '1.5 3D DFN circle', @() DFN('dim',3,'n',20,'shape','c','q',12); ...
                  '1.5 3D DFN square', @() DFN('dim',3,'n',20,'shape','s'); ...
                  '1.5 2D conditional',@() DFN('dim',2,'n',20,'asep',5,'dsep',0.001,'mit',50); ...
                  '1.5 intersections', @() Intersect(Field(DFN('dim',2,'n',40),'Line')); ...
                  '1.5 orientation',   @() Orientation(Field(DFN('dim',3,'n',20),'Poly')); ...
                  '1.5 clip 3D',       @() Clip(Field(DFN('dim',3,'n',20),'Orig'),[0,0,0,1,1,1]); ...
                  'merge: Scale_R1',   @() Scale_R1([1 2 3], 0, 1); ...
                  'merge: Bbox_R1',    @() Bbox_R1([0 0 0; 1 1 1]); ...
                  'merge: Stats_R1',   @() Stats_R1(rand(10,1)); ...
                  'merge: 1.5 Scale',  @() Scale(rand(5,1), 0, 1, 0, 90); ...
                  '1.5 flow chain',    @() Solve(Graph(Backbone(Pipe( ...
                        [0,0,0,1; 1,0,1,1], ...
                        Field(DFN('dim',2,'n',150),'Line'),'cnt'))),[1,0]); ...
                  }];
            end
            ok = true;
            for i = 1:size(checks,1)
                try
                    checks{i,2}();
                    fprintf('  PASS  %s\n', checks{i,1});
                catch ME
                    ok = false;
                    fprintf('  FAIL  %s : %s\n', checks{i,1}, ME.message);
                end
            end
            fprintf('smoketest: %s\n', string(missingToWord(ok)));
            function w = missingToWord(t), if t, w = "ALL PASS"; else, w = "FAILURES"; end, end
        end
    end

    %% ------------------------------------------------------------ UI construction
    methods (Access = public, Hidden = true)

        function pos = startupFigurePosition(~, wantW, wantH, scr)
            %STARTUPFIGUREPOSITION  Preferred size, shrunk to fit the primary
            %   monitor's usable area (screen minus taskbar and chrome), then
            %   centred there.
            %
            %   The floors used to be written max(720, screen - margins),
            %   which reads as "never smaller than 720" but actually means
            %   "pretend the screen is at least 720 wide". On anything
            %   narrower - a small laptop, a scaled high-DPI display, a
            %   secondary monitor - that produced a window WIDER than the
            %   screen, which is the complaint this function exists to fix.
            %   The floor is now capped by the screen itself.
            %
            %   scr is injectable so the fit can be tested against display
            %   sizes this machine does not have.
            if nargin < 4 || isempty(scr), scr = get(groot, 'ScreenSize'); end
            if numel(scr) ~= 4 || any(scr(3:4) <= 0)
                pos = [80 60 wantW wantH]; return   % headless / odd display
            end
            taskbar = 56;                           % bottom taskbar allowance
            chrome  = 48;                           % title bar + borders
            side    = 24;
            usableW = min(scr(3), max(480, scr(3) - 2*side));
            usableH = min(scr(4), max(400, scr(4) - taskbar - chrome));
            w = min(wantW, usableW);
            h = min(wantH, usableH);
            x = scr(1) + max(0, round((scr(3) - w)/2));
            y = scr(2) + max(0, round((scr(4) - h)/2));
            % never start off the left/bottom edge, never run past the right
            x = max(scr(1), min(x, scr(1) + scr(3) - w));
            y = max(scr(2), min(y, scr(2) + scr(4) - h));
            pos = [x y w h];
        end

        function buildUI(app)
            app.Fig = uifigure('Name', sprintf('ADFNE Workbench  %s', app.VERSION), ...
                'Position', app.startupFigurePosition(1480, 900), 'Color', app.BG, ...
                'Tag', 'ADFNE_GUI_main', ...
                'CloseRequestFcn', @(s,e) delete(app));
            app.RootGrid = uigridlayout(app.Fig, [4 1]);
            app.RootGrid.RowHeight   = {44, 40, '1x', 26};
            app.RootGrid.ColumnWidth = {'1x'};
            app.RootGrid.Padding = [8 8 8 8];
            app.RootGrid.RowSpacing = 6;
            app.RootGrid.BackgroundColor = app.BG;

            app.buildHeader(app.RootGrid);
            app.buildStateBar(app.RootGrid);

            body = uigridlayout(app.RootGrid, [1 2]);
            body.Layout.Row = 3;
            body.ColumnWidth = {470, '1x'};
            body.Padding = [0 0 0 0];
            body.ColumnSpacing = 8;
            body.BackgroundColor = app.BG;

            app.TabGroup = uitabgroup(body, ...
                'SelectionChangedFcn',@(s,e) app.onTabChanged());
            app.TabGroup.Layout.Column = 1;

            % The viewport is built first because it owns the view switch, and
            % the tab builders ask the current view what to offer -- building a
            % tab before the switch exists would let refreshEngineUI bail out on
            % its empty-ModeDD guard and leave the panel half-configured. Which
            % column each half lands in is set by Layout.Column, not by the
            % order they are built in.
            app.buildViewport(body);

            % Four tabs, and each one is a question about the rock mass: what
            % is it (Model), what did the face say (Conditioning), what can be
            % measured on it (Analysis), and does it flow. Plots and Export
            % used to sit here too, and neither was a question -- Plots was
            % chrome for the viewport already on screen, Export a terminal
            % action. They are the viewport dock and a dialog now.
            % Conditioning follows Model because it consumes Model's domain,
            % section plane and joint sets; see describeInherited.
            app.buildModelTab();
            app.buildConditioningTab();
            app.buildAnalysisTab();
            app.buildFlowTab();

            app.buildExportDialog();
            app.buildLog(app.RootGrid);
        end

        function buildHeader(app, root)
            hp = uipanel(root, 'BackgroundColor', app.ACCENT, 'BorderType','none');
            hp.Layout.Row = 1;
            g = uigridlayout(hp, [1 10]);
            g.ColumnWidth = {240, '1x', 64, 110, 90, 96, 110, 70, 90, 62};
            g.Padding = [12 6 12 6];
            g.ColumnSpacing = 6;
            g.BackgroundColor = app.ACCENT;

            t = uilabel(g, 'Text', 'ADFNE  Workbench', 'FontSize', 19, ...
                'FontWeight','bold', 'FontColor', [1 1 1]);
            t.Layout.Column = 1;

            app.PathLbl = uilabel(g, 'Text','', 'FontColor',[0.85 0.90 0.96], ...
                'FontSize', 11, 'VerticalAlignment','center');
            app.PathLbl.Layout.Column = 2;

            b0 = uibutton(g, 'Text','New', 'Tooltip', ...
                ['Start again: clears the model, the trace map, the results ' ...
                 'and the joint-set table, and puts every control back to its ' ...
                 'default. Asks first, because none of it can be recovered ' ...
                 'afterwards -- save the session if you want it back.'], ...
                'ButtonPushedFcn', @(s,e) app.onNewProject());
            b0.Layout.Column = 3;
            b1 = uibutton(g, 'Text','ADFNE folder…', 'ButtonPushedFcn', @(s,e) app.onPickRoot());
            b1.Layout.Column = 4;
            b2 = uibutton(g, 'Text','Self-test', 'ButtonPushedFcn', @(s,e) app.onSelfTest());
            b2.Layout.Column = 5;
            b3 = uibutton(g, 'Text','Export…', 'Tooltip', ...
                ['Write the model or the viewport to a file: PNG, PDF, SVG, ' ...
                 'FIG, VTK, MAT or CSV. Opens in its own window, because ' ...
                 'export is somewhere you go and leave rather than work in.'], ...
                'ButtonPushedFcn', @(s,e) app.openExportDialog());
            b3.Layout.Column = 6;
            b4 = uibutton(g, 'Text','Save session', 'ButtonPushedFcn', @(s,e) app.onSaveSession());
            b4.Layout.Column = 7;
            b5 = uibutton(g, 'Text','Load', 'ButtonPushedFcn', @(s,e) app.onLoadSession());
            b5.Layout.Column = 8;
            b6 = uibutton(g, 'Text','Console', 'Tooltip', ...
                'Advanced: run any ADFNE function against the current model', ...
                'ButtonPushedFcn', @(s,e) app.openConsole());
            b6.Layout.Column = 9;
            app.HelpBtn = uibutton(g, 'Text','Help', 'Tooltip', ...
                ['Open a copy of this window in which clicking anything - a tab, ' ...
                 'a button, a field, a table column, a dropdown item - explains it ' ...
                 'in the viewport instead of doing it. Nothing in the help window ' ...
                 'touches your model.'], ...
                'ButtonPushedFcn', @(s,e) app.openHelp());
            app.HelpBtn.Layout.Column = 10;
            b1.Tooltip = ['Point the workbench at the ADFNE library folder (the one ' ...
                'containing DFN.m). Found automatically when the app folder holds ' ...
                'lib\adfne; this is for a library kept elsewhere.'];
            b2.Tooltip = ['Check the dependencies and the ADFNE folder, and run a ' ...
                'few quick generations, without touching the current model.'];
            b4.Tooltip = ['Write everything - domain, joint sets, options, the ' ...
                'trace map or planes, the generated model, the results - to a .mat ' ...
                'session file, to pick up later or on another machine.'];
            b5.Tooltip = ['Read a session file back. Older sessions load: a control ' ...
                'the file does not know keeps its default.'];
        end

        function buildStateBar(app, root)
            app.StateBar = uipanel(root, 'BorderType','none', ...
                'BackgroundColor',[0.925 0.935 0.945]);
            app.StateBar.Layout.Row = 2;
            g = uigridlayout(app.StateBar,[1 2]);
            g.ColumnWidth = {'1x',150};
            g.Padding = [10 4 4 4]; g.ColumnSpacing = 8;
            g.BackgroundColor = app.StateBar.BackgroundColor;
            app.StateFactsLbl = uilabel(g,'Text', ...
                'NO MODEL  |  Set the rock-mass parameters, then generate.', ...
                'FontSize',11,'FontWeight','bold', ...
                'FontColor',[0.30 0.34 0.38], 'Tooltip', ...
                ['Persistent model state. Green means the displayed model ' ...
                 'matches every generative input; amber means GENERATE would ' ...
                 'build a different rock mass. Section-plane and display ' ...
                 'changes never make it amber.']);
            app.GenBtn = uibutton(g,'Text','GENERATE','FontWeight','bold', ...
                'BackgroundColor',app.ACCENT,'FontColor',[1 1 1], ...
                'Enable','off','Tooltip', ...
                ['Build the 3D network from the domain, joint sets and ' ...
                 'generation options. If conditioning is enabled, the same ' ...
                 'run also honours the active trace map. Viewing controls ' ...
                 'never regenerate or make the model out of date.'], ...
                'ButtonPushedFcn',@(s,e) app.onGenerate());
        end

        function buildViewport(app, body)
            % Everything about the picture now lives with the picture, in four
            % rows: what to show, the show itself, how it is styled, and what to
            % do with the result. Plot type and colour-by used to sit in a
            % 470 px tab of their own, competing for width with the modelling
            % controls while the thing they described was already on screen.
            app.ViewGrid = uigridlayout(body, [4 1]);
            right = app.ViewGrid;
            right.Layout.Column = 2;
            right.RowHeight = {30, '1x', 26, 36};
            right.Padding = [0 0 0 0];
            right.RowSpacing = 6;
            right.BackgroundColor = app.BG;

            % Row 1 -- selection. What am I looking at, how is it cut, what is
            % drawn and how is it coloured? All five belong beside the picture
            % they describe and beside the lists they filter, not on a tab away
            % from both.
            %
            % One row, and the widths are measured rather than guessed. The
            % contract needs the longest item of each dropdown plus 40 px, and
            % at 1366 x 768 this row has 872 px: View 133, Clip 177, Plot 165,
            % Colour 81, the checkbox 91, four labels 151, nine gaps 45. That
            % totals 843 and leaves the trailing '1x' to soak up the rest, so
            % nothing stretches. Plot used to BE the '1x' column, which is why
            % it grew into a bar half the window wide for the sake of the word
            % "Section plane".
            %
            % The row reads left to right as the chain of things that have to
            % be true: the 2D view enables 3D Intersect, which enables Clip.
            % Each control is greyed until the one to its left allows it, so
            % the order is the explanation. Do not reorder these three.
            %
            % Shortening the View items to "rock mass" and "section face" is
            % what bought the room. They now match the register vocabulary used
            % everywhere else, and the sentence they used to carry -- what a
            % section actually is -- is in the tooltip, where there is space
            % for the whole of it. ItemsData is untouched, so nothing that
            % reads the view is affected.
            vt = uigridlayout(right, [1 10]);
            vt.Layout.Row = 1;
            vt.ColumnWidth = {38, 136, 93, 31, 180, 33, 168, 49, 84, '1x'};
            vt.Padding = [0 0 0 0];
            vt.ColumnSpacing = 5;
            vt.BackgroundColor = app.BG;

            tp = ['How you look at the model, not what gets built. The network ' ...
                  'is always 3D. The 2D view is the traces where the section ' ...
                  'plane cuts it, which is what a tunnel face is. Switching ' ...
                  'never regenerates: same rock mass, same seed, same fractures.'];
            uilabel(vt,'Text','View','FontWeight','bold','Tooltip',tp);
            app.ModeDD = uidropdown(vt, 'Items', ...
                {'3D  | rock mass','2D  | section face'}, ...
                'ItemsData', {'3D','2D'}, 'Value','3D', 'Tooltip',tp, ...
                'ValueChangedFcn', @(s,e) app.onModeChanged(e.PreviousValue));

            % Cutting the model open is a viewing aid and nothing else -- the
            % network, the traces and every analysis are untouched by it -- so
            % it sits with the picture it changes rather than in the Section
            % plane panel, where it was three tabs from anything it affected.
            app.SecShowCB = uicheckbox(vt,'Text','3D Intersect', ...
                'Value',false,'Tooltip', ...
                ['Show the plane cutting the 3D model: the block, the plane, ' ...
                 'its normal, the fractures and the traces it makes. ' ...
                 'Available in the 2D section view.'], ...
                'ValueChangedFcn',@(s,e) app.onTogglePlane());
            tp = ['Hide part of the 3D network so the section plane is not ' ...
                  'buried inside it. Nothing is ever cut and the traces are ' ...
                  'untouched, so the model and every analysis are unaffected. ' ...
                  'Live only while 3D Intersect is ticked.' newline newline ...
                  'Hide front / back block  -  drop the fractures whose ' ...
                  'centre lies on one side. Front is the side the green ' ...
                  'normal arrow points into.' newline newline ...
                  'Only fractures with a trace  -  keep exactly the ' ...
                  'fractures that make the traces on the face, and nothing ' ...
                  'else. They lie on both sides of the plane, so this is not ' ...
                  'one of the two blocks: it is the answer to "which ' ...
                  'fractures am I actually looking at on this face?"'];
            uilabel(vt,'Text','Clip','Tooltip',tp);
            app.SecClipDD = uidropdown(vt, 'Items', ...
                {'no clipping','hide front block','hide back block', ...
                 'only fractures with a trace'}, ...
                'Value','no clipping','Tooltip',tp, ...
                'ValueChangedFcn',@(s,e) app.autoRender());

            tp = ['What to draw. The list follows the View and grows as ' ...
                  'you run analyses: a plot appears once the analysis behind ' ...
                  'it has produced something. If one you expect is missing, ' ...
                  'run its analysis, or check you are in the right view.'];
            uilabel(vt,'Text','Plot','FontWeight','bold','Tooltip',tp);
            app.PlotDD = uidropdown(vt,'Items',{'(generate a network first)'}, ...
                'Tooltip',tp,'ValueChangedFcn',@(s,e) app.autoRender());
            % default 'set': a network is usually built from several joint
            % sets, and telling them apart is the first thing you want to see
            tp = ['How fractures are coloured. Set gives each joint set its ' ...
                  'own colour, the same one everywhere in the app. Cluster ' ...
                  'colours by connected group, which needs an intersection ' ...
                  'analysis first. Uniform is one colour for all.'];
            uilabel(vt,'Text','Colour','FontWeight','bold','Tooltip',tp);
            app.ColorDD = uidropdown(vt,'Items',{'set','cluster','uniform'}, ...
                'Value','set','Tooltip',tp,'ValueChangedFcn',@(s,e) app.autoRender());

            app.PlotHost = uipanel(right, 'BackgroundColor', app.PANEL, ...
                'Title','Viewport', 'FontWeight','bold');
            app.PlotHost.Layout.Row = 2;
            app.PlotGrid = uigridlayout(app.PlotHost, [1 1]);
            app.PlotGrid.Padding = [4 4 4 4];
            app.PlotGrid.BackgroundColor = app.PANEL;
            app.ensureAxes('cart');
            % A blank 0--1 axes reads as a failed chart. Rendering makes it
            % visible again once there is something meaningful to show.
            app.Ax.Visible = 'off';

            app.buildDisplayDock(right);

            % Row 4 -- what to do with the result. RENDER and Auto-render sit
            % here, always visible, and deliberately NOT in the dock: they are a
            % matched pair for large models, where you untick Auto-render,
            % adjust, then draw once. A primary action that hides inside a
            % collapsed panel is the clipped-GENERATE bug wearing a hat.
            tb = uigridlayout(right, [1 8]);
            tb.Layout.Row = 4;
            tb.ColumnWidth = {92, 56, 104, 92, 84, 84, '1x', 108};
            tb.Padding = [0 0 0 0];
            tb.ColumnSpacing = 6;
            tb.BackgroundColor = app.BG;
            uibutton(tb,'Text','Reset view','Tooltip', ...
                'Back to the default camera for this plot.', ...
                'ButtonPushedFcn',@(s,e) app.onResetView());
            uibutton(tb,'Text','Fit','Tooltip', ...
                'Zoom so the whole model fits the viewport.', ...
                'ButtonPushedFcn',@(s,e) app.onFit());
            app.AutoCB = uicheckbox(tb,'Text','Auto-render','Value',true, ...
                'Tooltip',['Redraw as soon as any display setting changes. ' ...
                           'Untick on a large model and use RENDER when you ' ...
                           'have finished adjusting.']);
            app.RenderBtn = uibutton(tb,'Text','RENDER','FontWeight','bold', ...
                'BackgroundColor',app.ACCENT,'FontColor',[1 1 1],'Tooltip', ...
                ['Draw the current plot now. Only needed with Auto-render ' ...
                 'unticked, or to redraw after generating.'], ...
                'ButtonPushedFcn',@(s,e) app.renderPlot());
            uibutton(tb,'Text','Pop out','Tooltip', ...
                'Copy the current plot into a standard MATLAB figure window.', ...
                'ButtonPushedFcn',@(s,e) app.onPopOut());
            uibutton(tb,'Text','Save…','Tooltip', ...
                'Save the viewport as an image file.', ...
                'ButtonPushedFcn',@(s,e) app.onSaveImage());
            app.StatusLbl = uilabel(tb,'Text','','FontSize',11,'FontColor',[0.35 0.35 0.35]);
            app.StatusLbl.Layout.Column = 7;
            uibutton(tb,'Text','Clear viewport','Tooltip', ...
                'Empty the viewport. The model and its results are untouched.', ...
                'ButtonPushedFcn',@(s,e) app.onClearPlot());
        end

        function buildDisplayDock(app, right)
            %BUILDDISPLAYDOCK  Styling, in a drawer under the viewport.
            %   Styling is not selection: you set alpha and colormap while
            %   watching their effect, so these controls may never cover the
            %   picture they change. That rules out a popover and is the whole
            %   reason this is a dock. Collapsed it costs 26 px; expanded it
            %   takes its height from the viewport column, never from the
            %   control panel.
            app.DockGrid = uigridlayout(right, [2 2]);
            app.DockGrid.Layout.Row = 3;
            app.DockGrid.RowHeight = {26, 0};
            app.DockGrid.ColumnWidth = {'1x', 108};
            app.DockGrid.RowSpacing = 2; app.DockGrid.ColumnSpacing = 6;
            app.DockGrid.Padding = [6 0 0 0];
            app.DockGrid.BackgroundColor = app.BG;
            dl = uilabel(app.DockGrid,'FontSize',11,'Tooltip', ...
                'How the drawing looks. None of it changes the model.');
            app.inRegister(dl,'view', ...
                'Display  |  transparency, colours, decorations, camera');
            app.DockToggleBtn = uibutton(app.DockGrid,'Text','Display  v', ...
                'Tooltip','Show or hide the display settings.', ...
                'ButtonPushedFcn',@(s,e) app.toggleDock());
            app.DockToggleBtn.Layout.Column = 2;

            app.DockBody = uipanel(app.DockGrid,'BackgroundColor',app.PANEL, ...
                'BorderType','line','Visible','off');
            app.DockBody.Layout.Row = 2; app.DockBody.Layout.Column = [1 2];
            b = uigridlayout(app.DockBody,[3 8]);
            % The slider rows are taller than the checkbox row on purpose: a
            % uislider drops its tick labels when the row is too short, and an
            % Azimuth control with no scale on it is no better than the
            % colliding labels this replaced.
            b.RowHeight = {38,24,38};
            b.ColumnWidth = {74,'1x',72,58,66,116,52,'1x'};
            b.Padding = [8 4 8 4]; b.RowSpacing = 4; b.ColumnSpacing = 6;

            tp = ['How see-through the 3D fracture faces are. 0 is ' ...
                  'invisible, 1 solid. Around 0.6 lets you see into a dense ' ...
                  'network; lower it further when fractures hide each other. ' ...
                  '3D views only.'];
            uilabel(b,'Text','Face alpha','Tooltip',tp);
            app.AlphaSld = uislider(b,'Limits',[0 1],'Value',0.6, ...
                'MajorTicks',[0 0.5 1],'MajorTickLabels',{'0','.5','1'}, ...
                'Tooltip',tp,'ValueChangedFcn',@(s,e) app.autoRender());
            tp = ['Thickness of the trace lines in the 2D views, and of the ' ...
                  'lines drawn over the map plots.'];
            uilabel(b,'Text','Line width','Tooltip',tp);
            app.LWSpin = uispinner(b,'Value',1,'Limits',[0.1 6],'Step',0.1, ...
                'Tooltip',tp,'ValueChangedFcn',@(s,e) app.autoRender());
            tp = ['Colour scale for the map plots - density, connectivity, ' ...
                  'P21, kriging. It does not affect fractures coloured by ' ...
                  'set or cluster, which keep their own palette.'];
            uilabel(b,'Text','Colormap','Tooltip',tp);
            app.CmapDD = uidropdown(b,'Items', ...
                {'parula','turbo','jet','hot','cool','gray','copper','lines'}, ...
                'Tooltip',tp,'ValueChangedFcn',@(s,e) app.autoRender());

            app.BoxCB = uicheckbox(b,'Text','Region box','Value',true, ...
                'Tooltip','Outline the domain, so you can see what was clipped to it.', ...
                'ValueChangedFcn',@(s,e) app.autoRender());
            app.BoxCB.Layout.Row = 2; app.BoxCB.Layout.Column = [1 2];
            app.GridCB = uicheckbox(b,'Text','Grid','Value',true, ...
                'Tooltip','Axis grid lines.','ValueChangedFcn',@(s,e) app.autoRender());
            app.GridCB.Layout.Row = 2; app.GridCB.Layout.Column = 3;
            app.CbarCB = uicheckbox(b,'Text','Colorbar','Value',true, ...
                'Tooltip',['Scale bar beside the map plots. Without it a ' ...
                           'density map shows the pattern but not the values.'], ...
                'ValueChangedFcn',@(s,e) app.autoRender());
            app.CbarCB.Layout.Row = 2; app.CbarCB.Layout.Column = [4 5];
            app.LightCB = uicheckbox(b,'Text','Lighting (3D)','Value',true, ...
                'Tooltip',['Light the 3D fracture faces so their orientation ' ...
                           'reads. Untick for flat colour.'], ...
                'ValueChangedFcn',@(s,e) app.autoRender());
            app.LightCB.Layout.Row = 2; app.LightCB.Layout.Column = 6;
            app.Show3DCB = uicheckbox(b,'Text','3D DFN on section','Value',true, ...
                'Tooltip',['Show the surrounding fractures on the Section plane ' ...
                           'view. Untick to see the face and its traces alone.'], ...
                'ValueChangedFcn',@(s,e) app.autoRender());
            app.Show3DCB.Layout.Row = 2; app.Show3DCB.Layout.Column = [7 8];

            tp = 'Camera bearing, degrees. Rotates the model about the vertical.';
            az = uilabel(b,'Text','Azimuth','Tooltip',tp);
            az.Layout.Row = 3; az.Layout.Column = 1;
            app.AzSld = uislider(b,'Limits',[-180 180],'Value',-35, ...
                'MajorTicks',[-180 0 180],'MajorTickLabels',{'-180','0','180'}, ...
                'Tooltip',tp,'ValueChangedFcn',@(s,e) app.onViewSlider());
            app.AzSld.Layout.Row = 3; app.AzSld.Layout.Column = 2;
            tp = ['Camera height, degrees. 90 looks straight down, 0 is ' ...
                  'level with the model, negative looks up from below.'];
            el = uilabel(b,'Text','Elevation','Tooltip',tp);
            el.Layout.Row = 3; el.Layout.Column = 3;
            app.ElSld = uislider(b,'Limits',[-90 90],'Value',20, ...
                'MajorTicks',[-90 0 90],'MajorTickLabels',{'-90','0','90'}, ...
                'Tooltip',tp,'ValueChangedFcn',@(s,e) app.onViewSlider());
            app.ElSld.Layout.Row = 3; app.ElSld.Layout.Column = [4 5];
            xy = uibutton(b,'Text','XY','Tooltip','Look straight down: plan view.', ...
                'ButtonPushedFcn',@(s,e) app.setView([0 90]));
            xy.Layout.Row = 3; xy.Layout.Column = 6;
            xz = uibutton(b,'Text','XZ','Tooltip', ...
                'Look horizontally along -Y: front elevation.', ...
                'ButtonPushedFcn',@(s,e) app.setView([0 0]));
            xz.Layout.Row = 3; xz.Layout.Column = 7;
            iso = uibutton(b,'Text','ISO','Tooltip', ...
                'Back to the default isometric view, azimuth -35 elevation 20.', ...
                'ButtonPushedFcn',@(s,e) app.setView([-35 20]));
            iso.Layout.Row = 3; iso.Layout.Column = 8;
        end

        function [c, tag, note] = register(app, kind)
            %REGISTER  Colour, title suffix and tooltip line for one register.
            %   One place decides all three, so a panel cannot end up tinted
            %   as one register and worded as another.
            switch kind
                case 'gen'
                    c = app.REG_GEN;  tag = '3D rock mass';
                    note = ['GENERATIVE: part of what GENERATE builds from, so ' ...
                            'changing it marks the model out of date.'];
                case 'view'
                    c = app.REG_VIEW; tag = 'viewing only';
                    note = ['VIEWING ONLY: changes how you look at the model. ' ...
                            'It never regenerates and never marks the model ' ...
                            'out of date.'];
                case 'face'
                    c = app.REG_FACE; tag = '2D on the face';
                    note = ['ON THE FACE: measured in 2D on one mapped face. ' ...
                            'These are traces, not the 3D rock mass.'];
                case 'band'
                    % the same register as the face - field data, amber -
                    % with the tag saying it was mapped in a volume
                    c = app.REG_FACE; tag = '3D in a band';
                    note = ['IN THE BAND: joint planes mapped in 3D, in a slab ' ...
                            'centred on the section plane. Field data, not ' ...
                            'the generated rock mass.'];
                otherwise
                    error('ADFNE:Register','unknown register "%s"', kind);
            end
        end

        function h = inRegister(app, h, kind, title)
            %INREGISTER  Put one panel or label into a register.
            %   Tints it, appends the register tag to its title, and prefixes
            %   its tooltip with what the register means.
            [c, tag, note] = app.register(kind);
            if isprop(h,'Title')
                h.Title = sprintf('%s  ·  %s', title, tag);
                h.ForegroundColor = c;
            else
                h.Text = sprintf('%s  ·  %s', title, tag);
                h.FontColor = c;
            end
            % Idempotent: refreshCondUI and applyModeToTable re-register their
            % labels on every refresh, and a prefix applied each time would
            % stack the same paragraph up a dozen deep.
            old = strjoin(string(h.Tooltip), newline);
            % a label can move between the face and band registers, so strip
            % whichever register note is there before writing this one
            for k = {'gen','view','face','band'}
                [~, ~, other] = app.register(k{1});
                if startsWith(old, other)
                    old = strtrim(extractAfter(old, strlength(other)));
                end
            end
            if strlength(old) == 0
                h.Tooltip = note;
            else
                h.Tooltip = sprintf('%s\n\n%s', note, old);
            end
        end

        function toggleDock(app)
            app.setDockExpanded(~app.DockExpanded);
        end

        function setDockExpanded(app, expanded)
            if isempty(app.DockGrid) || ~isvalid(app.DockGrid), return, end
            app.DockExpanded = logical(expanded);
            rh = app.ViewGrid.RowHeight;
            if app.DockExpanded
                rh{3} = 158;
                app.DockGrid.RowHeight = {26,'1x'};
                app.DockBody.Visible = 'on';
                app.DockToggleBtn.Text = 'Display  ^';
            else
                rh{3} = 26;
                app.DockGrid.RowHeight = {26,0};
                app.DockBody.Visible = 'off';
                app.DockToggleBtn.Text = 'Display  v';
            end
            app.ViewGrid.RowHeight = rh;
        end

        function buildLog(app, root)
            app.LogGrid = uigridlayout(root, [2 2]);
            app.LogGrid.Layout.Row = 4;
            app.LogGrid.RowHeight = {26, 0};
            app.LogGrid.ColumnWidth = {'1x',72};
            app.LogGrid.RowSpacing = 2; app.LogGrid.ColumnSpacing = 6;
            app.LogGrid.Padding = [6 0 0 0];
            app.LogGrid.BackgroundColor = app.BG;
            app.LogSummary = uilabel(app.LogGrid,'Text','Log  |  ready', ...
                'FontSize',11,'FontColor',[0.30 0.34 0.38]);
            app.LogToggleBtn = uibutton(app.LogGrid,'Text','Log  ^', ...
                'Tooltip','Expand or collapse the full activity log.', ...
                'ButtonPushedFcn',@(s,e) app.toggleLog());
            app.LogToggleBtn.Layout.Column = 2;
            app.LogArea = uitextarea(app.LogGrid, 'Editable','off', ...
                'FontName','Consolas','FontSize',11,'Value',{''},'Visible','off');
            app.LogArea.Layout.Row = 2; app.LogArea.Layout.Column = [1 2];
            % Keyboard only. A figure-wide WindowButtonDownFcn used to drive
            % this too, and it is why dragging a 3D plot never rotated: in a
            % uifigure that handler takes the mouse-down, so the press never
            % reaches the axes and its Interactions never see the drag. The
            % rotate configuration was right the whole time; nothing was
            % delivering the event to it. It also explains why clicking the
            % Rotate 3D button twice appeared to help -- engaging an explicit
            % mode routes the drag through the mode machinery instead.
            %
            % Do not put a mouse handler on the figure. If click-driven help is
            % ever wanted back, it has to come from the controls themselves,
            % not from a listener that swallows every press in the window.
            app.Fig.WindowKeyReleaseFcn = @(s,e) app.showFocusHelp(s.CurrentObject);
        end

        % ---------------------------------------------------------- Model tab
        function buildModelTab(app)
            tab = uitab(app.TabGroup, 'Title','Model');
            shell = uigridlayout(tab, [2 1]);
            shell.RowHeight = {'1x', 44};
            shell.Padding = [0 0 0 0]; shell.RowSpacing = 0;
            g = uigridlayout(shell, [6 1]);
            g.Layout.Row = 1;
            % Sized to contents, with the '1x' on the joint-set table: that is
            % the one thing here anybody needs more of, and it used to be
            % pinned at 112 px while Options -- three fixed rows -- took every
            % spare pixel and spread them as blank panel.
            g.RowHeight = {app.panelH(2), app.panelH(1), 26, 22, '1x', app.panelH(7)};
            g.Scrollable = 'on';
            g.RowSpacing = 6; g.Padding = [0 10 0 10];

            % The View switch used to head this panel. It now sits above the
            % viewport, where what it changes is visible; its row is gone rather
            % than left blank, so the tab reclaims the height. This panel is
            % what the rock mass IS -- everything left here is generative.
            % Every tooltip below is written for someone meeting the parameter
            % for the first time, so the panel itself can stay uncluttered.
            r = 1;
            dp = uipanel(g,'BackgroundColor',app.PANEL,'Tooltip', ...
                ['The block of rock being modelled, in your own units - ' ...
                 'metres, usually. Set it before anything else: fractures are ' ...
                 'generated inside it and clipped to it, intensity (P32, P21) ' ...
                 'is measured per unit of it, preset fracture sizes are scaled ' ...
                 'to it, and the section plane offset is measured from its ' ...
                 'centre. Make it the volume you actually mapped.']);
            app.inRegister(dp,'gen','Domain (region of study)');
            dp.Layout.Row = r;
            % Two rows, X and Y on the first: the Termination row under
            % Options needed the height the third row was spending on Z.
            dg = uigridlayout(dp,[2 8]); dg.Padding=[8 4 8 4];
            % A coordinate is four or five characters. Giving the wells '1x'
            % stretched each one to 185 px of empty box; they are the width of
            % what goes in them now. Four fixed columns, not five with a
            % spacer: a spare column would collect the next auto-placed child
            % instead of letting the row wrap, and fixed columns already
            % leave the surplus alone.
            dg.ColumnWidth = {36, 62, 40, 62, 36, 62, 40, 62}; dg.ColumnSpacing = 6;
            dg.RowHeight = repmat({app.ROW_H},1,2);
            dg.RowSpacing = 4;
            lbls = {'X min','X max','Y min','Y max','Z min','Z max'};
            defs = [0 1 0 1 0 1];
            ends = {'Lower','Upper'}; axes3 = {'X','X','Y','Y','Z','Z'};
            app.RgnFields = gobjects(1,6);
            for i = 1:6
                tp = sprintf(['%s bound of the domain along %s, in your own ' ...
                    'units. Max must exceed min. The domain is what fractures ' ...
                    'are clipped to and what P32 is measured over.'], ...
                    ends{2-mod(i,2)}, axes3{i});
                uilabel(dg,'Text',lbls{i},'FontSize',11,'Tooltip',tp);
                app.RgnFields(i) = uieditfield(dg,'numeric','Value',defs(i), ...
                    'Tooltip',tp,'ValueChangedFcn',@(s,e) app.onDomainChanged());
            end

            r = r+1;
            xp = uipanel(g,'BackgroundColor',app.PANEL,'Tooltip', ...
                ['The plane the 2D view cuts through the model - a tunnel ' ...
                 'face, a borehole wall, an outcrop. It selects a view; it ' ...
                 'never changes the rock mass, so you can move it freely and ' ...
                 'the fractures stay put. Live in the 2D view only. ' ...
                 '3D Intersect and Clip, which show the plane inside the ' ...
                 'network and hide the fractures burying it, are above the ' ...
                 'viewport with the rest of the picture controls.']);
            app.inRegister(xp,'view','Section plane  (the 2D view)');
            xp.Layout.Row = r;
            % Clip and 3D Intersect used to sit on a second row here. They are
            % viewing aids that change the picture and nothing about the
            % geometry, so they moved to the top of the viewport; what is left
            % is the plane's own geometry, which is what conditioning imports
            % against and must stay visible in both views.
            % Two rows, not three pairs across one: three standard wells plus
            % their labels want about 500 px and this column gives 432, which
            % pushed Offset 36 px past the panel edge.
            % One row, three fields: the Centres row below needed the height
            % this panel's second row was spending on the offset alone.
            xg = uigridlayout(xp,[1 6]); xg.Padding=[8 4 8 4]; xg.RowSpacing = 4;
            xg.RowHeight = {app.ROW_H};
            xg.ColumnWidth = {28, 76, 46, 76, 46, 76};
            tp = ['Dip of the section plane: 0 - 90 degrees from horizontal, ' ...
                  'the ordinary geological dip. 0 is a flat-lying plane, 90 a ' ...
                  'vertical face, which is what a tunnel face is. Verified ' ...
                  'against the geometry actually generated, so what you type ' ...
                  'is the dip you get.'];
            uilabel(xg,'Text','Dip','FontSize',11,'Tooltip',tp);
            app.SecDipF = uieditfield(xg,'numeric','Value',90,'Limits',[0 90], ...
                'Tooltip',tp,'ValueChangedFcn',@(s,e) app.onSectionChanged());
            tp = ['Dip direction of the section plane: 0 - 360 degrees, ' ...
                  'measured in the XY plane ANTICLOCKWISE FROM +X - the ' ...
                  'mathematical convention, not a compass bearing. 0 gives a ' ...
                  'face whose normal points along +X, 90 along +Y. If your ' ...
                  'mapping is in compass bearings, set +X to north and enter ' ...
                  '360 minus the bearing.'];
            uilabel(xg,'Text','DipDir','FontSize',11,'Tooltip',tp);
            app.SecDirF = uieditfield(xg,'numeric','Value',0,'Limits',[0 360], ...
                'Tooltip',tp,'ValueChangedFcn',@(s,e) app.onSectionChanged());
            tp = ['How far the plane sits from the centre of the domain, ' ...
                  'measured along the plane normal, in domain units. 0 is the ' ...
                  'central section; positive moves it the way the green arrow ' ...
                  'points. Stepping it walks the plane through the model, ' ...
                  'which is how you see how much a face varies.'];
            uilabel(xg,'Text','Offset','FontSize',11,'Tooltip',tp);
            app.SecOffF = uieditfield(xg,'numeric','Value',0, ...
                'Tooltip',tp,'ValueChangedFcn',@(s,e) app.onSectionChanged());
            r = r+1;
            pr = uigridlayout(g,[1 2]); pr.Layout.Row = r;
            pr.ColumnWidth = {148,'1x'}; pr.Padding=[0 0 0 0]; pr.ColumnSpacing = 6;
            tp = ['Fills the joint-set table with a typical rock mass, with ' ...
                  'the fracture sizes scaled to your domain, so a first model ' ...
                  'does not start from a blank table. It is a starting point ' ...
                  'to edit against your own mapping, not an answer: every ' ...
                  'cell stays editable, and choosing a preset replaces ' ...
                  'whatever is in the table.'];
            uilabel(pr,'Text','Start from a preset','FontWeight','bold', ...
                'Tooltip',tp);
            app.PresetDD = uidropdown(pr, 'Items', app.presetNames(), ...
                'Tooltip',tp,'ValueChangedFcn', @(s,e) app.onPreset());

            r = r+1;
            hr = uigridlayout(g,[1 3]); hr.ColumnWidth = {'1x', 112, 104};
            hr.Padding = [0 0 0 0]; hr.ColumnSpacing = 6; hr.Layout.Row = r;
            app.SetHintLbl = uilabel(hr,'Text','Joint sets (3D)', ...
                'FontWeight','bold','FontSize',11);
            itp = strjoin({ ...
                'What the first column of the table holds.'
                ''
                'N      fractures of the set placed in the domain (before'
                '       clipping to it), which is what ADFNE''s generator'
                '       takes'
                'P32    the set''s fracture area per unit domain volume, the'
                '       intensity field mapping reports and FIT targets. On'
                '       GENERATE it is turned into a count by a short trial'
                '       run of the set - fixed seed, clipped to the domain -'
                '       so the built model carries about that P32; the state'
                '       bar shows what it actually came out at.'
                'P10    the set''s fractures per unit length along a scanline'
                '       parallel to the SECTION-PLANE NORMAL - a borehole'
                '       drilled square to the face you map. Turned into a'
                '       count the same way, with the trial counted along'
                '       lines through the domain. Turn the section plane to'
                '       turn the borehole.'
                ''
                'Switching converts the column both ways. Set-by-set P32 or'
                'P10 adds up: the state bar''s P32 is the sum over the sets.'
                'P33 (fracture volume per unit volume) is P32 times the Flow'
                'tab''s aperture, and is reported beside P32.'}, newline);
            otp = strjoin({ ...
                'How each set''s orientation scatter is drawn.'
                ''
                'dip, dipdir    ADFNE''s own: dip and dip direction drawn'
                '               independently, each with its own scatter'
                '               (dDip, dDDir - see the table''s tooltip).'
                'Fisher         one mean pole and one concentration kappa:'
                '               the von Mises-Fisher distribution on the'
                '               sphere, the standard joint-set model. The'
                '               kappa column is kappa (about 30 for a tight'
                '               set, 10 for a loose one); the next column'
                '               is unused. The mean pole is still Dip and'
                '               DipDir.'
                ''
                'bootstrap      poles resampled, with replacement, from'
                '               the mapped 3D joint planes assigned to the'
                '               set (by the file''s set column, else by the'
                '               set''s Dip / DipDir being the nearest). The'
                '               third column is an optional Fisher jitter'
                '               kappa about each resampled pole - 0 uses'
                '               them exactly. Needs planes loaded on the'
                '               Conditioning tab.'
                ''
                'biv. normal    dip and dip direction each normal about the'
                '               mean, independent: the columns are their'
                '               standard deviations in degrees (sd dip,'
                '               sd dir).'
                'Kent           the elliptical Fisher (Kent 1982): kappa as'
                '               for Fisher, and beta the ovalness - 0 is'
                '               Fisher, larger stretches the cluster. Positive'
                '               beta stretches it along strike, negative down'
                '               dip. Drawn in its concentrated form (kappa of'
                '               10 and up), with |beta| capped at 0.45 kappa.'
                'Bingham        the axial Bingham: density exp(-k1 s^2 - k2 d^2)'
                '               with s and d the pole''s components along'
                '               strike and down dip. k strk and k dip are k1,'
                '               k2: equal gives a round cluster, one near 0'
                '               a girdle. Exact rejection sampling (Kent,'
                '               Ganeiber & Mardia 2013).'
                ''
                'Switching converts the scatter columns both ways, as'
                'closely as the two models allow.'}, newline);
            app.OrientDD = uidropdown(hr, 'Items', ...
                {'dip, dipdir','Fisher','bootstrap','biv. normal','Kent','Bingham'}, ...
                'ItemsData', {'adfne','fisher','boot','bvn','kent','bingham'}, ...
                'Value','adfne', 'Tooltip', otp, ...
                'ValueChangedFcn', @(s,e) app.onOrientModelChanged());
            app.IntensityDD = uidropdown(hr, 'Items', {'N per set','P32 per set','P10 per set'}, ...
                'ItemsData', {'N','P32','P10'}, 'Value','N', 'Tooltip', itp, ...
                'ValueChangedFcn', @(s,e) app.onIntensityModeChanged());

            r = r+1;
            app.SetTable = uitable(g);
            app.SetTable.Layout.Row = r;

            r = r+1;
            op = uipanel(g,'BackgroundColor',app.PANEL, ...
                'Tooltip', ...
                ['How the network is drawn, as opposed to what it contains. ' ...
                 'The defaults are the sane ones: seed anything, circle, 24 ' ...
                 'facets, and both separation rules off. The two separation ' ...
                 'rules throw fractures away, so they change your intensity - ' ...
                 'leave them at 0 unless you mean it.']);
            app.inRegister(op,'gen','Options');
            op.Layout.Row = r;
            og = uigridlayout(op,[7 4]); og.Padding=[8 4 8 4];
            og.ColumnWidth = {80, app.FLD_W, 100, app.FLD_W}; og.ColumnSpacing = 6;
            og.RowHeight = repmat({app.ROW_H},1,7);
            og.RowSpacing = 4;
            tp = ['Starting point for the random number generator. The same ' ...
                  'seed with the same table and domain rebuilds the identical ' ...
                  'network, fracture for fracture, so a model is reproducible ' ...
                  'from this number alone. It is saved with the session.'];
            uilabel(og,'Text','Random seed','Tooltip',tp);
            app.SeedSpin = uispinner(og,'Value',7,'Limits',[0 1e6],'Step',1, ...
                'Tooltip',tp);
            app.RandSeedCB = uicheckbox(og,'Text','Randomise each run', ...
                'Value',false,'Tooltip', ...
                ['Draw a new seed on every GENERATE and write it into the box ' ...
                 'beside it, so a realisation you like is never lost - untick ' ...
                 'and the same seed is used again. Tick it to see how much ' ...
                 'the same statistics vary from one realisation to the next.']);
            app.RandSeedCB.Layout.Row = 1; app.RandSeedCB.Layout.Column = [3 4];
            stp = strjoin({ ...
                'How each fracture polygon is built, at the size drawn for it'
                '(a diameter, along the long axis for an elongated one).'
                ''
                'polygon      a regular q-gon inscribed in that diameter:'
                '             3 a triangle, 6 a hexagon, 24 looks round'
                'elongated    the same q-gon squashed to the Aspect ratio'
                '             below, long axis as chosen; aspect 2 along'
                '             strike is ADFNE''s own ellipse'
                'square            four corners, side = size (ADFNE''s)'
                'legacy quad       ADFNE 1.0''s irregular quadrilateral, built'
                '                  at twice the requested length - only for'
                '                  reproducing old results'}, newline);
            uilabel(og,'Text','Shape (3D)','Tooltip',stp);
            app.ShapeDD = uidropdown(og, 'Items', ...
                {'polygon','elongated','square','legacy quad'}, ...
                'ItemsData', {'c','e','s','l'}, 'Value','c', 'Tooltip',stp, ...
                'ValueChangedFcn',@(s,e) app.onShapeChanged());
            tp = ['Number of sides. Regular and elongated polygons only - ' ...
                  'square and legacy quad always have four corners, so this ' ...
                  'greys out for them. 24 already looks round; more only ' ...
                  'costs clipping and render time.'];
            uilabel(og,'Text','Sides q','Tooltip',tp);
            app.FacetSpin = uispinner(og,'Value',24,'Limits',[3 128],'Step',1, ...
                'Tooltip',tp);
            tp = ['Minimum angle between fracture poles, in degrees. A ' ...
                  'fracture whose pole falls within this of one already ' ...
                  'accepted is thrown away. 0 turns it off, which is the ' ...
                  'normal setting. It applies across all sets pooled ' ...
                  'together, and joint sets are tight by definition, so even ' ...
                  'a few degrees can discard most of the network - 5 degrees ' ...
                  'cut a 215-fracture model to 32. The log reports how many ' ...
                  'were rejected; the N column no longer means what it says.'];
            uilabel(og,'Text','Pole sep.','Tooltip',tp);
            app.ASepField = uieditfield(og,'numeric','Value',0,'Limits',[0 90], ...
                'Tooltip',tp);
            tp = ['Minimum distance between fracture centres, in domain ' ...
                  'units. A fracture whose centre falls within this of one ' ...
                  'already accepted is thrown away. 0 turns it off, which is ' ...
                  'the normal setting. It only bites once it approaches the ' ...
                  'mean fracture spacing; below that it rejects nothing.'];
            uilabel(og,'Text','Min. spacing','Tooltip',tp);
            app.DSepField = uieditfield(og,'numeric','Value',0,'Limits',[0 Inf], ...
                'Tooltip',tp);
            tp = strjoin({ ...
                'The distribution every set''s fracture size (a diameter) is'
                'drawn from, truncated to that set''s [Lmin, Lmax]. One law'
                'for the whole table; each set has its own parameters.'
                ''
                'exponential   ADFNE''s own: mean Lmean.  Lp is unused.'
                'log-normal    mean Lmean and standard deviation Lp, both'
                '              in domain units, of the untruncated law.'
                'power law     density proportional to L^-Lp between Lmin'
                '              and Lmax; Lmean is unused. Exponents of'
                '              about 2-3.5 are typical of mapped fracture'
                '              populations (Bonnet et al. 2001).'
                'uniform       every size between Lmin and Lmax equally'
                '              likely; Lmean and Lp unused.'
                'normal        mean Lmean, standard deviation Lp.'
                'Weibull       mean Lmean, shape Lp (1 is exponential,'
                '              larger is more peaked).'
                'gamma         mean Lmean, shape Lp (1 is exponential).'
                'bootstrap     sizes resampled, with replacement, from the'
                '              mapped 3D joint planes assigned to the set -'
                '              needs planes loaded on the Conditioning tab.'
                '              Lmin..Lmax still truncate; Lmean, Lp unused.'
                ''
                'Sizes come out of ADFNE''s generator as exponential; for'
                'the other two laws each polygon is rescaled about its'
                'centre to a size drawn from the chosen law, so centres,'
                'orientations and shapes are exactly as before.'}, newline);
            uilabel(og,'Text','Size law','Tooltip',tp);
            app.SizeLawDD = uidropdown(og, 'Items', ...
                {'exponential','log-normal','power law','uniform','normal', ...
                 'Weibull','gamma','bootstrap'}, ...
                'ItemsData', {'exp','logn','pow','unif','norm','weib','gam','boot'}, ...
                'Value','exp', 'Tooltip',tp, ...
                'ValueChangedFcn',@(s,e) app.onSizeLawChanged());
            % what Lp means is said in the table's own column header, which
            % is where the eye looks for it, rather than in a label here
            xtp = ['Which way the long axis of an elongated polygon points in ' ...
                   'its own plane: along the strike of the fracture (horizontal, ' ...
                   'ADFNE''s own choice), down its dip, or in a random ' ...
                   'direction drawn for each fracture.'];
            uilabel(og,'Text','Long axis','Tooltip',xtp);
            app.AxisDD = uidropdown(og,'Items',{'along strike','down dip','random'}, ...
                'ItemsData',{'strike','dip','random'},'Value','strike','Tooltip',xtp, ...
                'ValueChangedFcn',@(s,e) app.refreshStateBar());
            atp = strjoin({ ...
                'Elongated polygons only. Aspect is the long axis over the'
                'short one: 1 is the regular polygon, 2 is ADFNE''s ellipse.'
                'The size drawn for a fracture is its LONG-axis diameter.'
                ''
                'The three controls on this row are the MEAN aspect, the LAW'
                'the aspect follows from fracture to fracture, and its SPREAD'
                '(a standard deviation, in units of the ratio). The law is'
                'applied to the elongation, aspect minus 1, so the ratio can'
                'never fall below 1:'
                '  constant     every fracture the mean aspect'
                '  uniform      uniform about the mean, the spread its sd'
                '  normal       normal about the mean, cut at 1'
                '  log-normal   log-normal with that mean and sd'
                '  Weibull      Weibull with that mean and sd'
                '  gamma        gamma with that mean and sd'
                '  bootstrap    the mapped 3D planes'' own aspect ratios,'
                '               resampled - needs planes loaded'
                'With the mean at 1 or the spread at 0, every law is the'
                'constant. Bootstrap ignores both.'}, newline);
            uilabel(og,'Text','Aspect','Tooltip',atp);
            app.AspectField = uieditfield(og,'numeric','Value',2,'Limits',[1 100], ...
                'Tooltip',atp,'ValueChangedFcn',@(s,e) app.refreshStateBar());
            app.AspectLawDD = uidropdown(og,'Items', ...
                {'constant','uniform','normal','log-normal','Weibull','gamma','bootstrap'}, ...
                'ItemsData',{'const','unif','norm','logn','weib','gam','boot'},'Value','logn', ...
                'Tooltip',atp,'ValueChangedFcn',@(s,e) app.refreshStateBar());
            app.AspectSdField = uieditfield(og,'numeric','Value',0,'Limits',[0 100], ...
                'Tooltip',atp,'ValueChangedFcn',@(s,e) app.refreshStateBar());
            ctp = strjoin({ ...
                'Where fracture centres go. Orientation, size and shape are'
                'drawn exactly as before whatever is chosen here.'
                ''
                'uniform (Baecher)   every centre independent and uniform in'
                '                    the domain: ADFNE''s own, a Poisson process.'
                'nearest-nbr         nearest neighbour: centres cluster. A'
                '                    candidate is kept with'
                '                    probability (d0/d)^b, d its distance to the'
                '                    nearest centre already placed, d0 two per'
                '                    cent of the domain diagonal. The parameter'
                '                    is b: 0 is uniform, 1 mild clustering, 2-3'
                '                    strong (FracMan''s Nearest Neighbour).'
                'Levy-Lee            centres are the stops of a random walk whose'
                '                    step lengths follow a power law with tail'
                '                    exponent D, the fractal dimension of the'
                '                    set of centres (Clemo & Smith 1997). The'
                '                    parameter is D: near 3 fills space like'
                '                    uniform, 1-2 gives clusters within clusters.'
                ''
                'Both apply per set, in the domain and in a synthetic band.'
                'Compare 2D Trace Maps'' topology and the trace-map picture'
                'are where the clustering shows.'}, newline);
            uilabel(og,'Text','Centres','Tooltip',ctp);
            app.CentresDD = uidropdown(og,'Items',{'uniform','nearest-nbr','Levy-Lee'}, ...
                'ItemsData',{'poisson','nn','levy'},'Value','poisson','Tooltip',ctp, ...
                'ValueChangedFcn',@(s,e) app.onCentresChanged());
            uilabel(og,'Text','b  /  D','Tooltip',ctp);
            app.ClusterField = uieditfield(og,'numeric','Value',1.5,'Limits',[0 10], ...
                'Tooltip',ctp,'ValueChangedFcn',@(s,e) app.refreshStateBar());
            ttp = strjoin({ ...
                'Enhanced Baecher: termination at intersections.'
                ''
                'Fractures are placed in order - set 1 first, so the table'
                'order is the age order - and this many percent of those'
                'that intersect an earlier fracture are cut back to the'
                'earlier fracture''s plane, keeping the side their own'
                'centre is on. 0 leaves every fracture whole (Baecher);'
                '100 terminates every one that meets an older fracture,'
                'the way a younger joint set abuts an older one.'
                ''
                'It changes connectivity, not just geometry: terminated'
                'fractures end ON another fracture, so Y nodes appear on'
                'a face and clusters link differently. Compare 2D Trace'
                'Maps'' Topology tab is where to see it.'}, newline);
            uilabel(og,'Text','Terminate %','Tooltip',ttp);
            app.TermField = uieditfield(og,'numeric','Value',0,'Limits',[0 100], ...
                'Tooltip',ttp,'ValueChangedFcn',@(s,e) app.refreshStateBar());
            tl = uilabel(og,'Text','of those meeting an older fracture', ...
                'FontSize',11,'FontColor',[.45 .45 .45],'Tooltip',ttp);
            tl.Layout.Row = 7; tl.Layout.Column = [3 4];

            bg = uigridlayout(shell,[1 3]); bg.Layout.Row = 2;
            bg.ColumnWidth = {'1x',130,130}; bg.Padding=[10 4 10 4];
            addBtn = uibutton(bg,'Text','Add set','Tooltip', ...
                ['Add a joint set: one more row in the table, filled with ' ...
                 'typical values for you to edit.'], ...
                'ButtonPushedFcn',@(s,e) app.onAddSet());
            addBtn.Layout.Column = 2;
            removeBtn = uibutton(bg,'Text','Remove set','Tooltip', ...
                ['Delete the selected row of the joint-set table, or the last ' ...
                 'row. The table may be emptied; GENERATE and FIT then say so.'], ...
                'ButtonPushedFcn',@(s,e) app.onRemoveSet());
            removeBtn.Layout.Column = 3;

            app.applyModeToTable();
        end

        % ------------------------------------------------------- Analysis tab
        function buildAnalysisTab(app)
            tab = uitab(app.TabGroup, 'Title','Analysis');
            g = uigridlayout(tab,[5 1]);
            app.AnaGrid = g;
            % The results table takes the '1x'. Everything above it is sized
            % to its contents, so the one thing that grows without limit is
            % the one thing you accumulate.
            g.RowHeight = {22,190,132,30,'1x'};
            g.Scrollable = 'on';
            g.RowSpacing = 6; g.Padding = [10 10 10 10];

            % Every row here is a fixed height on purpose. This grid is
            % Scrollable so the tab survives a short screen, and a scrollable
            % uigridlayout gives '1x' rows their MINIMUM height rather than the
            % leftover space - which left this list showing 4 of its 12 entries.
            tp = ['What can be measured on the current model. The list ' ...
                  'follows the View: 3D offers properties of the rock mass, ' ...
                  '2D offers what you can measure on the section. Each entry ' ...
                  'names the ADFNE function behind it. Results collect in the ' ...
                  'table below and unlock the plots that draw them.'];
            uilabel(g,'Text','Available analyses  (Ctrl/Shift to select several)', ...
                'FontWeight','bold','Tooltip',tp);
            app.AnaList = uilistbox(g,'Multiselect','on','Items',{},'Tooltip',tp, ...
                'ValueChangedFcn',@(s,e) app.refreshAnalysisParams());
            app.AnaList.Layout.Row = 2;

            % Parameters appear with the analysis that reads them. Each one is
            % inert until its own analysis is highlighted, which is what makes
            % hiding it safe: a control may be hidden only when it cannot
            % affect the next run. Nothing generative or geometric is hidden
            % anywhere -- the section plane in particular stays visible in
            % both views, because it sets the face conditioning imports
            % against and its preview is most wanted before anything exists.
            %
            % A "Support" spinner used to sit here, offering "the window a
            % cell is judged over" for the connectivity measures. Nothing ever
            % read it. ADFNE's ConnectivityField2D(lines, La, gm, gn, rm, rn)
            % has no support argument at all, and rm/rn are the target cells
            % rather than a window, so the control could not have worked as
            % described without changing the ADFNE calls. Removed rather than
            % left promising something it never did.
            app.AnaParamPanel = uipanel(g,'BackgroundColor',app.PANEL, ...
                'Title','Parameters for the selected analyses','Tooltip', ...
                ['Settings for the analyses you have highlighted. Each field ' ...
                 'appears only while an analysis that reads it is selected, ' ...
                 'so what is shown here is what the next run will use.']);
            app.AnaParamPanel.Layout.Row = 3;
            pg = uigridlayout(app.AnaParamPanel,[4 6]); pg.Padding=[8 4 8 4];
            pg.ColumnWidth = {84,62,58,54,40,'1x'};
            pg.RowHeight = repmat({app.ROW_H},1,4);
            pg.RowSpacing = 4; pg.ColumnSpacing = 5;
            app.AnaParamGrid = pg;

            tp = ['Cells per side of the sampling grid, for every map ' ...
                  'analysis: density, P21, P22, the connectivity fields and ' ...
                  'kriging. Higher is finer but slower - the connectivity ' ...
                  'field costs roughly N^4. The grid covers the section face, ' ...
                  'so a non-square face gets a non-square grid.'];
            gl = place(uilabel(pg,'Text','Grid N','Tooltip',tp),   1,1);
            app.GridSpin = place(uispinner(pg,'Value',20,'Limits',[2 200], ...
                'Tooltip',tp), 1,2);
            app.AnaGridRow = [gl, app.GridSpin];

            tp = ['Which axis "Traces on plane" slices along. It is a ' ...
                  'separate, axis-aligned cut used by that analysis alone - ' ...
                  'not the Section plane on the Model tab, which is the one ' ...
                  'the 2D view uses. Called a slice axis so that only one ' ...
                  'thing in this app is called a plane.'];
            sl1 = place(uilabel(pg,'Text','Slice axis','Tooltip',tp),    2,1);
            app.PlaneDD  = place(uidropdown(pg,'Items',{'Z =','Y =','X ='}, ...
                                 'ItemsData',{'z','y','x'},'Tooltip',tp),  2,2);
            tp = ['Where along that axis the "Traces on plane" cut is taken, ' ...
                  'in domain units.'];
            sl2 = place(uilabel(pg,'Text','Slice at','Tooltip',tp),  2,3);
            app.PlaneVal = place(uieditfield(pg,'numeric','Value',0.5, ...
                'Tooltip',tp),     2,4);
            app.AnaSliceRow = [sl1, app.PlaneDD, sl2, app.PlaneVal];

            tp = ['Borehole radius, in domain units, for "Borehole sampling". ' ...
                  'A fracture counts as intersected if it comes within this ' ...
                  'of the borehole axis.'];
            bl1 = place(uilabel(pg,'Text','Borehole r','Tooltip',tp),   3,1);
            app.BhR      = place(uieditfield(pg,'numeric','Value',0.02, ...
                'Tooltip',tp),    3,2);
            tp = ['Where the borehole stands, in domain units: its X and Y, ' ...
                  'then the Z it runs from and to. It is vertical. Used by ' ...
                  '"Borehole sampling", which is the synthetic equivalent of ' ...
                  'logging a hole through the model.'];
            bl2 = place(uilabel(pg,'Text','Borehole XY','Tooltip',tp),  4,1);
            app.BhX1 = place(uieditfield(pg,'numeric','Value',0.5,'Tooltip',tp),  4,2);
            app.BhY1 = place(uieditfield(pg,'numeric','Value',0.5,'Tooltip',tp),  4,3);
            bl3 = place(uilabel(pg,'Text','Z','Tooltip',tp),            4,4);
            app.BhZ1 = place(uieditfield(pg,'numeric','Value',0,'Tooltip',tp),    4,5);
            app.BhZ2 = place(uieditfield(pg,'numeric','Value',1,'Tooltip',tp),    4,6);
            app.AnaBhRow = [bl1, app.BhR, bl2, app.BhX1, app.BhY1, bl3, ...
                            app.BhZ1, app.BhZ2];

            app.AnaParamHint = uilabel(pg,'Text', ...
                'Highlight an analysis above; anything it needs appears here.', ...
                'FontSize',11,'FontColor',[.45 .45 .45],'Tooltip', ...
                ['Most analyses take no settings at all. The ones that do - ' ...
                 'the map analyses, Traces on plane and Borehole sampling - ' ...
                 'put their fields here when you highlight them.']);
            app.AnaParamHint.Layout.Row = 1;
            app.AnaParamHint.Layout.Column = [1 6];
            function h = place(h, r, c), h.Layout.Row = r; h.Layout.Column = c; end

            bg = uigridlayout(g,[1 3]); bg.Layout.Row = 4;
            bg.ColumnWidth = {'1x',140,140}; bg.Padding=[0 0 0 0];
            app.AnaRunBtn = uibutton(bg,'Text','RUN SELECTED','FontWeight','bold', ...
                'BackgroundColor',app.ACCENT,'FontColor',[1 1 1], 'Tooltip', ...
                ['Run every highlighted analysis in turn. Results add to the ' ...
                 'table below rather than replacing it, and each one unlocks ' ...
                 'its plot in the Plot list above the viewport.'], ...
                'ButtonPushedFcn',@(s,e) app.onRunAnalysis());
            uibutton(bg,'Text','Select all','Tooltip', ...
                ['Highlight every analysis in the list. Some are slow on a ' ...
                 'large model - the connectivity fields most of all.'], ...
                'ButtonPushedFcn',@(s,e) set(app.AnaList,'Value',app.AnaList.Items));
            uibutton(bg,'Text','Clear results','Tooltip', ...
                ['Throw away every result. The model and its fractures are ' ...
                 'untouched; only the measurements and the plots that need ' ...
                 'them go.'], ...
                'ButtonPushedFcn',@(s,e) app.onClearResults());

            app.ResTable = uitable(g,'ColumnName',{'Metric','Value'}, ...
                'ColumnWidth',{240,'auto'},'Data',cell(0,2),'Tooltip', ...
                ['Every scalar the analyses have produced, newest run last. ' ...
                 'Grids and point sets are not shown here - they are drawn ' ...
                 'in the viewport. Everything here is written to the MAT export.']);
            app.ResTable.Layout.Row = 5;
        end

        % -------------------------------------------------- Conditioning tab
        function buildConditioningTab(app)
            tab = uitab(app.TabGroup, 'Title','Conditioning');
            g = uigridlayout(tab,[14 1]);
            % No '1x' here. This grid is Scrollable, and a scrollable grid
            % gives a '1x' row its MINIMUM once the content stops fitting --
            % which on this tab it does, so the info box collapsed to a single
            % line. Fixed heights and let the tab scroll.
            % Row 4 is the source panel. It has a title and TWO rows now --
            % the file label and Show traces share the second -- so it needs
            % panelH(2). At a bare 50 the whole second row was cut off and
            % the Show traces button was invisible.
            % Rows 2 and 3 were three lines of prose between the heading and
            % the first control. One line each now, with the full wording on
            % their tooltips -- which is where this tab already keeps its
            % explanation -- and that paid for the compare row.
            % Row 4 has three rows now: the band thickness for a 3D source
            % lives on the third, so panelH(3).
            g.RowHeight = {20, 18, 18, app.panelH(3), 24, 96, 26, 28, 18, 96, ...
                           20, 48, 58, 92};
            g.Scrollable = 'on';
            g.RowSpacing = 6; g.Padding = [10 10 10 10];

            uilabel(g,'Text','1.  The field data', ...
                'FontWeight','bold','FontSize',12,'Tooltip', ...
                ['What was mapped: either the traces on one face (a 2D trace ' ...
                 'map), or joint planes in a volume - a band centred on the ' ...
                 'section plane, as thick as you say. Either can be drawn ' ...
                 'for you from statistics, or imported from real mapping. ' ...
                 'Steps 2 and 3 are both optional and independent - you can ' ...
                 'fit without conditioning, or condition without fitting.']);

            uilabel(g,'Text','Where field data enters the model.', ...
                'FontSize',11,'FontColor',[.45 .45 .45],'WordWrap','on', ...
                'Tooltip',['Where field data enters the model. Fit the joint ' ...
                 'sets to what you measured on a face, and make the model ' ...
                 'reproduce its traces exactly. The rest of the rock mass ' ...
                 'stays stochastic.' newline newline 'Steps 2 and 3 are ' ...
                 'independent: you can fit without conditioning, or condition ' ...
                 'without fitting.']);

            % This tab modifies the model, it does not replace it: a trace fixes
            % the plane its fracture lies in but not the rotation about it, the
            % size or the centre, and those come from the joint sets. Say so,
            % rather than leaving the dependency to be discovered.
            app.CondInheritLbl = uilabel(g,'Text','', ...
                'FontSize',11,'FontColor',[.35 .35 .35],'WordWrap','on');

            sp = uipanel(g,'BackgroundColor',app.PANEL,'Tooltip', ...
                ['Where the traces come from. Synthetic draws them from the ' ...
                 'statistics in the table below - useful for trying the ' ...
                 'workflow. Imported reads a face you mapped.']);
            app.CondSrcPanel = sp;
            app.inRegister(sp,'face','Where the field data comes from');
            % Two rows, not one: a mapped filename is as long as the person who
            % named it, and squeezed into the fourth column of one row even
            % "(no file loaded)" truncated to "(no file ...".
            % Every child here is placed explicitly. The Show button shares
            % row 2 with the file label rather than taking a fourth column on
            % row 1: the Source dropdown needs about 200 px for "synthetic
            % from 2D statistics", and a fourth column would leave it 146.
            sg = uigridlayout(sp,[3 3]); sg.Padding=[8 4 8 4];
            sg.ColumnWidth = {56,'1x',104};
            sg.RowHeight = repmat({app.ROW_H},1,3); sg.RowSpacing = 4;
            tp = ['Where the field data comes from.' newline newline ...
                  '2D: the traces on the section face, drawn from the ' ...
                  'statistics table below or imported from a mapped face.' ...
                  newline '3D: joint planes in a band - the section plane ' ...
                  'given a thickness - drawn from the table or imported ' ...
                  'from a scan or photogrammetry export. A 3D plane carries ' ...
                  'its dip, dip direction and size, so FIT recovers all ' ...
                  'three; a face can only give size and count.' newline newline ...
                  'Import sets this for you from what it reads.'];
            sl = uilabel(sg,'Text','Source','Tooltip',tp);
            sl.Layout.Row = 1; sl.Layout.Column = 1;
            app.CondSrcDD = uidropdown(sg,'Items', ...
                {'2D: synthetic from statistics','2D: imported trace map', ...
                 '3D: synthetic planes in a band','3D: imported joint planes'}, ...
                'ItemsData',{'syn','file','syn3','file3'},'Tooltip',tp, ...
                'ValueChangedFcn',@(s,e) app.onCondSourceChanged());
            app.CondSrcDD.Layout.Row = 1; app.CondSrcDD.Layout.Column = 2;
            ib = uibutton(sg,'Text','Import file…','Tooltip', strjoin({ ...
                'Read field data and set Source from what the file holds.'
                ''
                'A 2D trace map: CSV/text, 4-5 columns'
                '   u1 v1 u2 v2 [set]   in the plane of the face, from its centre'
                ''
                '3D joint planes, local coordinates with the origin at the'
                'centre of the band and axes parallel to the domain''s:'
                '   xc yc zc dip dipdir size        6 columns (size = diameter)'
                '   xc yc zc nx ny nz radius        7 columns'
                '   x y z corners, one polygon per block, blank line between'
                '   .mat holding a cell array of n-by-3 corner lists'
                'With a header row the names decide (dip / nx / set ...).'
                ''
                'See examples\trace_maps and examples\joint_planes.'}, newline), ...
                'ButtonPushedFcn',@(s,e) app.onImportField());
            ib.Layout.Row = 1; ib.Layout.Column = 3;
            btp = ['Thickness of the 3D band: the mapped volume is the section ' ...
                   'plane (dip / dipdir / offset on the Model tab) extended ' ...
                   'this far either side, and clipped to the domain. Used by ' ...
                   'the 3D sources only. Make it enclose the planes you mapped ' ...
                   '- the info box below reports how far off the plane they lie.'];
            bl = uilabel(sg,'Text','Band','Tooltip',btp);
            bl.Layout.Row = 3; bl.Layout.Column = 1;
            bg = uigridlayout(sg,[1 3]); bg.ColumnWidth = {app.FLD_W,'fit','fit'};
            bg.Padding = [0 0 0 0]; bg.ColumnSpacing = 6;
            bg.Layout.Row = 3; bg.Layout.Column = [2 3];
            app.BandThkF = uieditfield(bg,'numeric','Value',1,'Limits',[1e-6 Inf], ...
                'Tooltip',btp,'ValueChangedFcn',@(s,e) app.onBandChanged());
            cbtp = strjoin({ ...
                'Which planes a mapped band holds.'
                ''
                'UNTICKED   the planes whose CENTRES lie in the band - what'
                '           the synthetic band draws by default, and what a'
                '           file of centres and sizes usually means.'
                'TICKED     every plane that CUTS the band, as a scan or a'
                '           photogrammetric slab records. A plane of extent h'
                '           across the band is cut with probability going as'
                '           (thickness + h), so big and steep planes are over-'
                '           represented and small, band-parallel ones under.'
                '           FIT then weights each plane by 1 / (thickness + h)'
                '           - h the exact extent of that polygon across the'
                '           band - in every statistic it estimates: sizes,'
                '           orientation means and scatters, aspect ratio.'
                '           The count is unaffected: P32 in the band is what'
                '           it is. A synthetic band draws cutting planes too,'
                '           so the correction can be checked against a known'
                '           answer.'}, newline);
            app.BandCutCB = uicheckbox(bg,'Text','cut the band (scan)', ...
                'Value',false,'FontSize',11,'Tooltip',cbtp, ...
                'ValueChangedFcn',@(s,e) app.onBandChanged());
            cltp = strjoin({ ...
                'The planes that cut the band are also CLIPPED at its faces:'
                'the polygon in the file is only the part inside the band,'
                'as a scan of a slab delivers it. Their sizes are then'
                'CENSORED - each is a lower bound on the true size - and a'
                'plain fit reads them as complete and comes out small.'
                ''
                'Ticked, FIT flags every plane with a corner on a face and'
                'corrects the sizes by simulated sampling, as the 2D fit'
                'does for trace lengths: planes are drawn from the set, cut'
                'by the band and clipped at its faces exactly as the scan'
                'did, and the size scale is found at which their mean size'
                'matches the mean that was measured. Works whether one'
                'plane is clipped or every one, under any size law. Clipped'
                'planes are left out of the aspect fit - a clipped polygon'
                'has no shape of its own. Orientation and the count need no'
                'correction. Only with "cut the band"; the synthetic band'
                'clips its planes too when this is on, so the correction can'
                'be checked against a known answer.'}, newline);
            app.BandClipCB = uicheckbox(bg,'Text','clipped at faces', ...
                'Value',false,'FontSize',11,'Tooltip',cltp,'Enable','off', ...
                'ValueChangedFcn',@(s,e) app.onBandChanged());
            app.CondFileLbl = uilabel(sg,'Text','(no file loaded)','FontSize',11, ...
                'FontColor',[.45 .45 .45],'Tooltip', ...
                'The trace file currently loaded.');
            app.CondFileLbl.Layout.Row = 2;
            app.CondFileLbl.Layout.Column = [1 2];
            % "Fit to these traces" names something the user has never seen.
            % This draws them, on the face, in the viewport -- so "these"
            % has a referent before anyone is asked to fit anything to it.
            % A toggle, not a push button. The trace map is a preview of an
            % INPUT, and once it was showing there was no obvious way back:
            % re-picking the same View does nothing -- MATLAB fires no callback
            % when a dropdown is set to the value it already has -- so the only
            % route was a round trip through the 3D view. "Hide traces" is one
            % click, whatever the View happens to say.
            app.CondPreviewBtn = uibutton(sg,'state','Text','Show traces','Tooltip', ...
                ['Draw the field data in the viewport: the trace map on the ' ...
                 'face, or the joint planes in their band. An imported set is ' ...
                 'exactly what FIT reads; a synthetic one is drawn from the ' ...
                 'table below with the current seed. Works before anything ' ...
                 'has been generated. For a trace map the dashed rectangle ' ...
                 'is the mapped window that P21 is measured over.'], ...
                'ValueChangedFcn',@(s,e) app.onToggleTraceMap());
            app.CondPreviewBtn.Layout.Row = 2;
            app.CondPreviewBtn.Layout.Column = 3;

            % Not the joint sets. These describe TRACES on the face - 2D
            % lines - and only matter when the source is synthetic. The
            % resemblance to the Model tab's table caused real confusion.
            app.CondStatsLbl = uilabel(g,'FontSize',11,'WordWrap','on','Tooltip', ...
                'Used only when Source = synthetic.');
            app.inRegister(app.CondStatsLbl,'face', ...
                'Synthetic trace statistics  -  not joint sets');

            app.CondTable = uitable(g);
            app.CondTable.Tooltip = strjoin({ ...
                'Statistics for SYNTHETIC traces. These are 2D lines on the'
                'face, not joint sets - the Model tab holds those.'
                ''
                'N          traces in this row'
                'Dir (deg)  mean direction in the plane of the face,'
                '           measured from the face''s own u axis'
                'Kappa      how tightly they cluster about it; higher is'
                '           tighter, about 25 for a well-defined set'
                ''
                'L min, L mean, L max   trace length: exponential with mean'
                'L mean, truncated to [L min, L max], in domain units.'}, newline);
            app.CondTable.ColumnName = {'N','Dir (deg)','Kappa','L min','L mean','L max','Lp -'};
            app.CondTable.ColumnEditable = true(1,7);
            app.CondTable.ColumnFormat = repmat({'bank'},1,7);
            % 'fit' plus the row-number column overflowed the 470 px panel, so
            % the table grew a horizontal scrollbar and cut "L max" off. The
            % row number adds nothing here, exactly as on the joint-set table.
            app.CondTable.RowName = {};
            app.CondTable.ColumnWidth = {48,66,54,50,60,52,62};
            app.TraceSets = [60 45 25 0.3 1.0 3.0 0];
            app.PlaneSets = [30 45 -25 180 -25 0.3 1.0 3.0 0];
            app.applyCondTableLayout();

            op = uigridlayout(g,[1 3]); op.ColumnWidth = {'1x',104,104};
            op.Padding=[0 0 0 0]; op.ColumnSpacing = 6;
            uilabel(op,'Text','');
            uibutton(op,'Text','Add row','Tooltip', ...
                ['Another synthetic family, turned 90 degrees from the ' ...
                 'last so it crosses it.'], ...
                'ButtonPushedFcn',@(s,e) app.onAddTraceSet());
            uibutton(op,'Text','Remove row','Tooltip', ...
                'Drop the last row. One row always remains.', ...
                'ButtonPushedFcn',@(s,e) app.onRemoveTraceSet());

            % --- two independent things you can do with a map ---------------
            % Heading and action on one line. The button used to run the full
            % width of the panel for a caption that named its own subject
            % twice; the traces it fits to are step 1, immediately above.
            fr = uigridlayout(g,[1 2]);
            fr.ColumnWidth = {'1x', 152};
            fr.Padding = [0 0 0 0]; fr.ColumnSpacing = 8;
            ftp = ['Inverse fitting: work backwards from the traces in step 1 ' ...
                   'to the 3D sizes and counts that would produce them. ' ...
                   'Answers "what rock mass gives this face?" It changes the ' ...
                   'Model tab joint-set table and nothing else. Press Show ' ...
                   'traces above to see the map it reads.'];
            uilabel(fr,'Text','2.  Fit the joint sets  (optional)', ...
                'FontWeight','bold','FontSize',12,'Tooltip',ftp);
            fb = uibutton(fr,'Text','FIT DFN TO TRACES', ...
                'FontWeight','bold','BackgroundColor',app.ACCENT_LT, ...
                'ButtonPushedFcn',@(s,e) app.onFitSets());
            fb.Tooltip = ftp;
            app.FitBtn = fb;

            tp = ['What FIT would change on the Model tab: the count and ' ...
                  'mean size of each joint set, before and after. A section ' ...
                  'is a biased sample - it favours large fractures and cuts ' ...
                  'them short - so the fitted values are not the trace ' ...
                  'statistics themselves.'];
            app.FitLbl = uilabel(g,'FontSize',11,'Tooltip',tp);
            % Tagged generative, not face: FIT reads the face but writes the
            % joint-set table, and what it changes is the rock mass.
            app.inRegister(app.FitLbl,'gen', ...
                'Fitted joint sets  (run FIT to see what it would change)');
            % short headers: MATLAB enforces a minimum column width per
            % header, and the long ones clipped inside a 470 px panel
            app.FitTable = uitable(g,'ColumnName', ...
                {'Set','N was','N now','Lmean was','Lmean now'}, ...
                'ColumnWidth',{36,58,58,86,86},'Data',cell(0,5), ...
                'ColumnFormat',repmat({'char'},1,5),'Tooltip',tp);

            uilabel(g,'Text','3.  Make the model reproduce it   (optional)', ...
                'FontWeight','bold','FontSize',12,'Tooltip', ...
                ['Conditioning: put a real fracture in the model for every ' ...
                 'mapped trace or plane, so the model reproduces what you ' ...
                 'mapped exactly. A trace fixes the plane a fracture lies in ' ...
                 'but not its rotation about the trace, its size or its ' ...
                 'centre - those still come from the joint sets. A 3D plane ' ...
                 'fixes all of it, and goes in as it is. The rest of the rock ' ...
                 'mass stays stochastic.']);
            cg = uigridlayout(g,[2 2]); cg.ColumnWidth = {'1x',175};
            cg.RowHeight = {22,20}; cg.Padding=[0 0 0 0];
            cg.RowSpacing = 2; cg.ColumnSpacing = 6;
            app.CondCB = uicheckbox(cg,'Text', ...
                'Condition the model on this map','Value',false,'Tooltip', ...
                ['While this is ticked, the persistent GENERATE action above ' ...
                 'honours the trace map. The state bar reports the source ' ...
                 'used by the built model.'], ...
                'ValueChangedFcn',@(s,e) app.refreshCondUI());
            app.CondSetDD = uidropdown(cg,'Items',{'auto (nearest orientation)'}, ...
                'ItemsData',{0},'Tooltip', ...
                ['Which joint set the mapped traces belong to, since a trace ' ...
                 'carries no orientation of its own beyond its direction in ' ...
                 'the face. Auto assigns each trace to the set whose ' ...
                 'orientation best explains it; pick one to force them all ' ...
                 'into it. A file with a fifth column overrides this.']);
            app.CondExclCB = uicheckbox(cg,'Text', ...
                'Mapped face is complete  -  stochastic fractures may not add traces', ...
                'Value',true,'Tooltip', ...
                ['Tick when your map records every trace on the face: the ' ...
                 'stochastic fractures are then kept off it, so the section ' ...
                 'shows your traces and no others. Untick if the map is ' ...
                 'partial - only what you could reach or see - and the model ' ...
                 'may add its own traces alongside yours.']);
            app.CondExclCB.Layout.Row = 2; app.CondExclCB.Layout.Column = [1 2];

            % Neither step tells you whether it worked. This does: the map you
            % asked for and the section the model actually produces, side by
            % side, with the numbers a fit is judged on.
            cr = uigridlayout(g,[2 2]);
            cr.ColumnWidth = {'1x', 190};
            cr.RowHeight = {26, 26};
            cr.Padding = [0 0 0 0]; cr.ColumnSpacing = 8; cr.RowSpacing = 4;
            ctp = ['Compare the mapped face with the generated section, both ' ...
                   'measured over the window the map covers, on the four things ' ...
                   'a face can tell you: intensity (count, P21), orientation ' ...
                   '(an axial rose and Kuiper''s test), trace length (the two ' ...
                   'cumulative curves and the KS test) and topology (I / Y / X ' ...
                   'node shares after Sanderson & Nixon 2015).' newline newline ...
                   'The Summary tab scores every measure and says what each ' ...
                   'difference reads as; the other tabs are the pictures.' ...
                   newline newline ...
                   'After FIT, this is how you check it: many size and count ' ...
                   'combinations give the same P21, so read the distributions ' ...
                   'and not just the means. With conditioning on, every mapped ' ...
                   'trace is in the generated section, so the two should agree ' ...
                   'almost exactly. Needs a generated model and a trace map.'];
            uilabel(cr,'Text','Check the result against the map', ...
                'FontSize',11,'FontColor',[.45 .45 .45],'Tooltip',ctp);
            app.CondCompareBtn = uibutton(cr,'Text','Compare 2D Trace Maps', ...
                'Tooltip',ctp,'ButtonPushedFcn',@(s,e) app.onCompareTraceMaps());
            rtp = ['Go back to the last model generated with conditioning ' ...
                   'off, and to the joint sets that produced it.' newline newline ...
                   'This undoes FIT as well as conditioning: FIT rewrites the ' ...
                   'joint-set table, so restoring the model without the table ' ...
                   'it came from would leave the two disagreeing.' newline newline ...
                   'Nothing else is touched -- the trace map, the domain and ' ...
                   'the section plane stay as they are, so you can try a ' ...
                   'different fit straight away.'];
            uilabel(cr,'Text','Undo fitting and conditioning', ...
                'FontSize',11,'FontColor',[.45 .45 .45],'Tooltip',rtp);
            app.CondRestoreBtn = uibutton(cr,'Text','Restore original DFN', ...
                'Tooltip',rtp,'ButtonPushedFcn',@(s,e) app.onRestoreBaseline());

            app.CondInfo = uitextarea(g,'Editable','off','FontName','Consolas', ...
                'FontSize',11,'Value',{'No trace map yet.'},'Tooltip', ...
                ['What the current trace map contains. Check the u and v ' ...
                 'extents against the face size on the Model tab: a map ' ...
                 'covering far less than the face usually means the ' ...
                 'coordinates are in different units or measured from a ' ...
                 'different origin.']);
            app.refreshCondUI();
        end

        function refreshCondUI(app)
            if isempty(app.CondCB), return, end
            app.refreshRestoreBtn();
            app.describeInherited();
            app.refreshEngineUI();          % the Model button reflects this tab
            on = @(b) matlab.lang.OnOffSwitchState(b);
            src = app.CondSrcDD.Value;
            syn = any(strcmp(src, {'syn','syn3'}));
            is3 = app.is3DSource();
            % The field data itself is always available: loading it and
            % fitting the joint sets to it are useful on their own, and used
            % to be locked behind the conditioning checkbox. Only step 3
            % - actually honouring it - depends on that box.
            app.CondSrcDD.Enable  = on(true);
            % Import is deliberately always live: it sets Source itself from
            % what it reads, so disabling it here would mean having to select
            % a file source that has no file before you could choose one.
            if is3, fn = app.PlanesFileName; else, fn = app.CondFileName; end
            if isempty(fn)
                app.CondFileLbl.Text = '(no file loaded)';
                app.CondFileLbl.FontColor = [0.45 0.45 0.45];
            elseif syn
                app.CondFileLbl.Text = [fn '  (loaded, not in use)'];
                app.CondFileLbl.FontColor = [0.55 0.35 0.10];
            else
                app.CondFileLbl.Text = fn;
                app.CondFileLbl.FontColor = [0.10 0.35 0.10];
            end
            if ~isempty(app.BandThkF) && isvalid(app.BandThkF)
                app.BandThkF.Enable = on(is3);
            end
            if ~isempty(app.BandCutCB) && isvalid(app.BandCutCB), app.BandCutCB.Enable = on(is3); end
            if ~isempty(app.BandClipCB) && isvalid(app.BandClipCB)
                app.BandClipCB.Enable = on(is3 && app.BandCutCB.Value);
            end
            % The statistics table is 2D trace families or 3D joint-plane
            % families, depending on the source; the two stores are kept
            % apart so switching back and forth loses nothing.
            app.applyCondTableLayout();
            % uitable's Enable is on|off|inactive, not the on/off enum
            % Both branches go through inRegister, so this label keeps its
            % register tag and tint whatever state it is in. Colour means
            % register here and nowhere else: active versus inactive is said
            % in words, which is the stronger signal anyway and leaves the
            % amber of the face register meaning only one thing.
            % one line each: the row is 24 px, and the register tag is
            % appended to whatever is written here
            if is3
                reg = 'band'; what = 'Synthetic planes  (N = in the band)';
            else
                reg = 'face'; what = 'Synthetic traces  -  not joint sets';
            end
            app.inRegister(app.CondSrcPanel, reg, 'Where the field data comes from');
            if syn && isempty(app.CondTable.Data)
                app.CondTable.Enable = 'on';
                app.inRegister(app.CondStatsLbl, reg, [what '  -  EMPTY: Add row, or Import file']);
            elseif syn
                app.CondTable.Enable = 'on';
                app.inRegister(app.CondStatsLbl, reg, [what '.  Edit, then GENERATE']);
            else
                app.CondTable.Enable = 'off';
                % a disabled control with no stated reason looks broken
                app.inRegister(app.CondStatsLbl, reg, [what '  -  INACTIVE, the file is in use']);
            end
            % the buttons name what they act on
            if ~isempty(app.FitBtn) && isvalid(app.FitBtn)
                if is3, app.FitBtn.Text = 'FIT DFN TO PLANES';
                else,   app.FitBtn.Text = 'FIT DFN TO TRACES'; end
            end
            if ~isempty(app.CondCompareBtn) && isvalid(app.CondCompareBtn)
                if is3, app.CondCompareBtn.Text = 'Compare 3D Joint Planes';
                else,   app.CondCompareBtn.Text = 'Compare 2D Trace Maps'; end
            end
            if is3
                app.CondCB.Text = 'Condition the model on these planes';
                app.CondExclCB.Text = ['Mapped band is complete  -  stochastic ' ...
                    'fractures may not reach into it'];
            else
                app.CondCB.Text = 'Condition the model on this map';
                app.CondExclCB.Text = ['Mapped face is complete  -  stochastic ' ...
                    'fractures may not add traces'];
            end
            app.syncTraceMapBtn();
            app.CondExclCB.Enable = on(app.CondCB.Value);
            app.CondSetDD.Enable  = on(app.CondCB.Value);
            % joint sets available to assign traces to
            k = size(app.Sets,1);
            it = [{'auto (nearest orientation)'}, ...
                  arrayfun(@(i) sprintf('joint set %d',i), 1:k, 'UniformOutput',false)];
            dat = num2cell(0:k);
            old = app.CondSetDD.Value;
            app.CondSetDD.Items = it; app.CondSetDD.ItemsData = dat;
            if any(cellfun(@(v) isequal(v,old), dat)), app.CondSetDD.Value = old;
            else, app.CondSetDD.Value = 0; end
        end

        function applyCondTableLayout(app)
            %APPLYCONDTABLELAYOUT  Six trace columns, or eight plane columns.
            if isempty(app.CondTable) || ~isvalid(app.CondTable), return, end
            if app.is3DSource()
                cn = {'N','Dip','dDip','DipDir','dDDir','Lmin','Lmean','Lmax','Lp'};
                cn{9} = app.lpHeader();
                app.PlaneSets = app.padSets(app.PlaneSets);
                if size(app.PlaneSets,2) ~= 9 && ~isempty(app.PlaneSets)
                    app.PlaneSets = [30 45 -25 180 -25 0.3 1.0 3.0 0];
                end
                app.PlaneSets = app.padSets(app.PlaneSets);
                if isempty(app.PlaneSets), app.PlaneSets = zeros(0,9); end
                data = app.PlaneSets;
                cw = {40,40,44,50,48,40,46,40,40};
                tp = strjoin({ ...
                    'Statistics for SYNTHETIC joint planes in the band. The'
                    'same columns as the Model tab''s joint sets, but N here is'
                    'the number of planes IN THE BAND, not in the whole domain.'
                    ''
                    'Dip, DipDir, dDip, dDDir and the sizes follow the joint-set'
                    'table''s conventions exactly - hover it for those.'
                    ''
                    'Used only when Source = 3D synthetic. FIT should recover'
                    'these from the planes it draws: that is the test of it.'}, newline);
            else
                cn = {'N','Dir (deg)','Kappa','L min','L mean','L max', app.lpHeader()};
                app.TraceSets = app.padTraceSets(app.TraceSets);
                if size(app.TraceSets,2) ~= 7 && ~isempty(app.TraceSets)
                    app.TraceSets = [60 45 25 0.3 1.0 3.0 0];
                end
                if isempty(app.TraceSets), app.TraceSets = zeros(0,7); end
                data = app.TraceSets;
                cw = {48,66,54,50,60,52,62};
                tp = strjoin({ ...
                    'Statistics for SYNTHETIC traces. These are 2D lines on the'
                    'face, not joint sets - the Model tab holds those.'
                    ''
                    'N          traces in this row'
                    'Dir (deg)  mean direction in the plane of the face,'
                    '           measured from the face''s own u axis'
                    'Kappa      how tightly they cluster about it; higher is'
                    '           tighter, about 25 for a well-defined set'
                    ''
                    'L min, L mean, L max, Lp   trace length, in domain units,'
                    'from the SIZE LAW chosen under Options on the Model tab,'
                    'truncated to [L min, L max]. Lp is that law''s extra'
                    'parameter, exactly as on the joint-set table: unused for'
                    'the exponential (ADFNE''s own) and the uniform, the sd for'
                    'log-normal and normal, the exponent for the power law,'
                    'the shape for Weibull and gamma. Bootstrap resamples the'
                    'lengths of an imported trace map, and needs one loaded.'}, newline);
            end
            if ~isequal(app.CondTable.ColumnName(:)', cn)
                app.CondTable.ColumnName = cn;
                app.CondTable.ColumnEditable = true(1, numel(cn));
                app.CondTable.ColumnFormat = repmat({'bank'}, 1, numel(cn));
                app.CondTable.ColumnWidth = cw;
                app.CondTable.Data = data;
            elseif ~isequal(app.CondTable.Data, data)
                app.CondTable.Data = data;
            end
            app.CondTable.Tooltip = tp;
        end

        function harvestCondTable(app)
            %HARVESTCONDTABLE  Fold the visible statistics into their store.
            %   An empty table is a legitimate state: it goes back as an
            %   empty store of the right width, not as the old contents.
            if isempty(app.CondTable) || ~isvalid(app.CondTable), return, end
            d = app.CondTable.Data;
            if isempty(d)
                if app.is3DSource(), app.PlaneSets = zeros(0,9);
                else,                app.TraceSets = zeros(0,7); end
            elseif size(d,2) == 9, app.PlaneSets = d;
            elseif any(size(d,2) == [6 7])
                app.TraceSets = app.padTraceSets(d);
                if size(d,2) ~= 7, app.CondTable.Data = app.TraceSets; end
            end
        end

        function onCondSourceChanged(app)
            %ONCONDSOURCECHANGED  A new source: swap the table, the preview
            %   plot and the info box over, and drop a preview of the old one.
            app.harvestCondTable();
            was = app.PlotDD.Value;
            if any(strcmp(was, {'Trace map','Mapped planes'}))
                app.CondPreviewBtn.Value = false; app.onToggleTraceMap();
            end
            app.refreshCondUI();
            app.refreshPlotTypes();
            if app.is3DSource(), app.describePlanes(); else, app.describeTraceMap(); end
            app.refreshStateBar();
        end

        function onBandChanged(app)
            %ONBANDCHANGED  The band moved: redraw it if it is up, re-describe.
            if ~isempty(app.BandClipCB) && isvalid(app.BandClipCB)
                app.BandClipCB.Enable = app.iff(app.BandCutCB.Value && app.is3DSource(), 'on', 'off');
            end
            app.describePlanes();
            app.refreshStateBar();
            if strcmp(app.PlotDD.Value, 'Mapped planes'), app.renderPlot(); end
        end

        function describeInherited(app)
            %DESCRIBEINHERITED  What this tab takes from the Model tab.
            if isempty(app.CondInheritLbl), return, end
            r = [app.RgnFields.Value];
            % One line of numbers, with the reason on the tooltip. The numbers
            % stay visible -- this dependency is the whole reason the tab sits
            % after Model -- but the sentence explaining it need not.
            app.CondInheritLbl.Text = sprintf( ...
                'From Model:  domain %gx%gx%g  |  face %g / %g / %g  |  %d set(s)', ...
                r(2)-r(1), r(4)-r(3), r(6)-r(5), app.SecDipF.Value, ...
                app.SecDirF.Value, app.SecOffF.Value, size(app.Sets,1));
            app.CondInheritLbl.Tooltip = sprintf([ ...
                'Taken from the Model tab, not set here:' newline newline ...
                '  domain          %g-%g x %g-%g x %g-%g' newline ...
                '  section plane   dip %g / dipdir %g / offset %g' newline ...
                '  joint sets      %d' newline newline ...
                'A trace fixes the plane its fracture lies in, but not the ' ...
                'rotation about it, the size or the centre. Those come from ' ...
                'the joint sets, which is why both tabs are needed together.'], ...
                r(1), r(2), r(3), r(4), r(5), r(6), app.SecDipF.Value, ...
                app.SecDirF.Value, app.SecOffF.Value, size(app.Sets,1));
        end

        function onAddTraceSet(app)
            d = app.CondTable.Data;
            if size(d,2) == 9
                row = [30 45 -25 180 -25 0.3 1.0 3.0 0];
                row(9) = app.defaultLp(row);
                if ~isempty(d), row(4) = mod(d(end,4) + 90, 360); end
            else
                row = [60 45 25 0.3 1.0 3.0 0];
                row(7) = app.defaultLp(app.traceRowsAsSets(row));
                if ~isempty(d), row(2) = mod(d(end,2) + 90, 360); end
                d = app.padTraceSets(d);
            end
            app.CondTable.Data = [d; row];
            app.harvestCondTable();
        end

        function onRemoveTraceSet(app)
            %ONREMOVETRACESET  Drop the selected row, or the last one - down
            %   to none. The guards are on GENERATE, FIT and Show.
            d = app.CondTable.Data;
            if isempty(d), return, end
            r = size(d,1);
            try
                sel = app.CondTable.Selection;
                if ~isempty(sel), r = sel(1); end
            catch, end %#ok<CTCH>
            d(min(max(r,1), size(d,1)), :) = [];
            app.CondTable.Data = d;
            app.harvestCondTable();
            app.refreshCondUI();
        end

        function onImportTraces(app)
            %ONIMPORTTRACES  The 2D-only importer, kept for scripts that call
            %   it by name; the button goes through onImportField now.
            [f, pth] = uigetfile({'*.csv;*.txt','Trace map (*.csv, *.txt)'}, ...
                'Import a mapped trace map');
            figure(app.Fig);
            if isequal(f,0), return, end
            try
                M = readmatrix(fullfile(pth,f));
                if size(M,2) < 4
                    error('ADFNE:TraceCols', ...
                        ['Expected at least 4 columns: u1 v1 u2 v2 [set].' newline ...
                         'Coordinates are in the plane of the mapped face, in ' ...
                         'the same units as the domain.']);
                end
                app.importTraceMatrix(M, f);
            catch ME
                uialert(app.Fig, ME.message, 'Import failed');
            end
        end

        function onShowTraces(app)
            %ONSHOWTRACES  Turn the trace-map preview on. Kept as a name of its
            %   own because it reads better at call sites than setting a
            %   button's Value and invoking its callback by hand.
            if ~isempty(app.CondPreviewBtn) && isvalid(app.CondPreviewBtn)
                app.CondPreviewBtn.Value = true;
            end
            app.onToggleTraceMap();
        end

        function onToggleTraceMap(app)
            %ONTOGGLETRACEMAP  Show or dismiss the trace map.
            %   "Fit to these traces" names something the user has never been
            %   shown: a statistics table if the source is synthetic, a file
            %   name if it is imported, and in neither case the traces
            %   themselves. This draws them, so "these" has a referent.
            %
            %   The traces live on the face, so this is a 2D-view plot; asking
            %   for it from the 3D view switches the view rather than refusing.
            if isempty(app.CondPreviewBtn) || ~isvalid(app.CondPreviewBtn), return, end
            if ~app.CondPreviewBtn.Value
                app.dismissTraceMap();
                return
            end
            % remember what was showing, so dismissing has somewhere to go back
            % to. Switch the view BEFORE selecting the plot: onModeChanged
            % clears a trace map that is already up, and would otherwise throw
            % away the one we are in the middle of putting there.
            nm = app.previewPlotName();
            app.harvestCondTable();
            if (strcmp(app.CondSrcDD.Value,'syn') && isempty(app.TraceSets)) || ...
               (strcmp(app.CondSrcDD.Value,'syn3') && isempty(app.PlaneSets))
                app.CondPreviewBtn.Value = false;
                if strcmp(app.CondSrcDD.Value,'syn'), w = 'trace statistics';
                else, w = 'plane statistics'; end
                app.guideNoSynthetic(w);
                app.syncTraceMapBtn();
                return
            end
            if ~any(strcmp(app.PlotDD.Value, {'Trace map','Mapped planes'}))
                app.PrevPlotTM = app.PlotDD.Value;
            end
            % the trace map lives on the face (2D view); the planes live in
            % the rock mass (3D view). Switch the view first: onModeChanged
            % clears a preview that is already up.
            want2D = strcmp(nm, 'Trace map');
            if app.is2DView() ~= want2D
                prev = app.ModeDD.Value;
                if want2D, app.ModeDD.Value = '2D'; else, app.ModeDD.Value = '3D'; end
                app.onModeChanged(prev);
            end
            if any(strcmp(nm, app.PlotDD.Items))
                app.PlotDD.Value = nm;
                app.syncPlaneCB();
                app.renderPlot();
                % describe what was drawn, not what happens to be stored
                try
                    if want2D
                        sec = app.sectionGeometry(app.liveRgn());
                        app.describeTraceMap(app.traceMapFor(sec, true));
                    else
                        app.describePlanes();
                    end
                catch, end %#ok<CTCH>
            end
            app.syncTraceMapBtn();
        end

        function dismissTraceMap(app)
            %DISMISSTRACEMAP  Put back whatever the trace map replaced.
            if ~any(strcmp(app.PlotDD.Value,{'Trace map','Mapped planes'})), app.syncTraceMapBtn(); return, end
            back = app.PrevPlotTM;
            if isempty(back) || ~any(strcmp(back, app.PlotDD.Items))
                back = '';
                for it = string(app.PlotDD.Items)
                    if ~any(strcmp(it,{'Trace map','Mapped planes'})), back = char(it); break, end
                end
            end
            if ~isempty(back)
                app.PlotDD.Value = back;
                app.syncPlaneCB();
                app.renderPlot();
            end
            app.syncTraceMapBtn();
        end

        function syncTraceMapBtn(app)
            %SYNCTRACEMAPBTN  Keep the toggle honest when the plot changes by
            %   any other route -- the Plot list, a view change, GENERATE.
            if isempty(app.CondPreviewBtn) || ~isvalid(app.CondPreviewBtn), return, end
            on = any(strcmp(app.PlotDD.Value,{'Trace map','Mapped planes'}));
            app.CondPreviewBtn.Value = on;
            if app.is3DSource(), what = 'planes'; else, what = 'traces'; end
            if on, app.CondPreviewBtn.Text = ['Hide ' what];
            else,  app.CondPreviewBtn.Text = ['Show ' what];
            end
        end

        function onCompareTraceMaps(app)
            %ONCOMPARETRACEMAPS  The map you asked for against the one you got.
            if app.is3DSource(), app.onComparePlanes(); return, end
            %   Fitting and conditioning both aim the model at a mapped face,
            %   and neither says whether it landed. This measures the two
            %   trace maps over the SAME window -- the part of the face the
            %   map actually covers, which is what the fitter targets and
            %   what P21 has to be divided by -- and compares them on the
            %   four things a face can tell you about a fracture network:
            %
            %     intensity     count and P21, judged against Poisson noise
            %     orientation   an axial rose, and Kuiper's two-sample test
            %     trace length  the two empirical CDFs, and the KS test
            %     topology      I / Y / X node proportions after Sanderson &
            %                   Nixon (2015), and connections per line
            %
            %   The first version showed one number per property, which
            %   could not do the job: a mean direction says nothing about two
            %   sets 90 degrees apart, and many size/count pairs share a P21.
            %   The tests used here assume no distribution, and both maps
            %   are cut by the same window, so the censoring is the same on
            %   both sides and the comparison stays fair even though neither
            %   side's lengths are the true fracture sizes.
            %
            %   Kolmogorov-Smirnov and Kuiper p-values are the asymptotic
            %   forms of Stephens (1970) as given in Press et al., Numerical
            %   Recipes 14.3; node topology is Sanderson & Nixon (2015).
            %   References in README.md.
            if isempty(app.Model.fnm)
                uialert(app.Fig, ['Generate a model first: there is no ' ...
                    'section to compare the map against.'], 'Nothing to compare');
                return
            end
            if ~isfield(app.Model,'sec') || isempty(app.Model.sec)
                app.computeSection();
            end
            sec = app.Model.sec;
            gen = sec.lines;
            geo = app.sectionGeometry(app.Model.rgn);
            cl = app.busy('comparing trace maps...', false, 'compare'); %#ok<NASGU>
            try
                ref = app.traceMapFor(geo, true);
            catch ME
                uialert(app.Fig, ME.message, 'Could not build the trace map');
                return
            end
            if isempty(ref)
                uialert(app.Fig, ['No trace map to compare against. Import a ' ...
                    'face, or fill in the synthetic statistics.'], 'No trace map');
                return
            end

            % Measure both over the window the MAP covers, not the whole face:
            % a map over half the face divided by the whole understates P21 by
            % exactly the area ratio, which is the trap the README records.
            [win, area] = app.mapWindow(ref, geo);
            box = [win(1) win(3) win(2) win(4)];
            refW = Clip(ref, box); if ~isempty(refW), refW(all(refW==0,2),:) = []; end
            genW = Clip(gen, box); if ~isempty(genW), genW(all(genW==0,2),:) = []; end

            c = app.compareStats(refW, genW, win, area);
            app.buildCompareWindow(c, geo, sec, refW, genW);
            app.log(sprintf(['Compared trace maps: mapped %d traces / P21 %.4g, ' ...
                'generated %d / P21 %.4g; KS p %.2g, Kuiper p %.2g.'], ...
                c.ref.n, c.ref.P21, c.gen.n, c.gen.P21, c.ksP, c.kuP), 'ok');
        end

        function c = compareStats(app, R, G, win, area)
            %COMPARESTATS  Every number the comparison window shows.
            %   Kept apart from the drawing so a test can check the numbers:
            %   a map compared with itself must come out identical on every
            %   measure, a rotated copy must be caught by the orientation test
            %   and a rescaled one by the length test.
            c = struct('win', win, 'area', area);
            c.ref = app.traceStats(R, area);
            c.gen = app.traceStats(G, area);
            c.Lr = app.traceLen(R);  c.Lg = app.traceLen(G);
            c.Ar = app.traceDir(R);  c.Ag = app.traceDir(G);

            % count, against what sampling alone would give: a Poisson count
            % of n has a standard deviation of sqrt(n), so two realisations of
            % ONE network routinely differ by that much
            c.countZ = NaN;
            if c.ref.n > 0, c.countZ = (c.gen.n - c.ref.n) / sqrt(c.ref.n); end

            % trace length: the whole distribution, not its mean
            [c.ksD, c.ksP, c.ksAt] = app.ks2(c.Lr, c.Lg);

            % orientation is axial - 179 and 1 are two degrees apart - so
            % everything works on doubled angles. Kuiper rather than KS on the
            % circle because it gives the same answer wherever the circle is
            % cut, and unlike a mean direction it copes with several sets.
            [c.dirR, c.concR] = app.axialMean(c.Ar);
            [c.dirG, c.concG] = app.axialMean(c.Ag);
            c.dirDiff = mod(c.dirG - c.dirR + 90, 180) - 90;
            [c.kuV, c.kuP] = app.kuiper2(2*c.Ar, 2*c.Ag);
            c.roseEdges = 0:10:180;
            c.roseR = app.roseFractions(c.Ar, c.Lr, c.roseEdges);
            c.roseG = app.roseFractions(c.Ag, c.Lg, c.roseEdges);

            % topology, to a tolerance a digitised abutment can meet. Kept
            % tight: at 0.5% of the window side a generated section - which
            % has no abutments by construction - picked up chance contacts
            % on one end in ten.
            c.tol  = 0.002 * sqrt(max(area, eps));
            c.topR = app.topology(R, c.tol, area);
            c.topG = app.topology(G, c.tol, area);
        end

        function L = traceLen(~, T)
            L = zeros(0,1);
            if ~isempty(T), L = sqrt(sum((T(:,3:4)-T(:,1:2)).^2, 2)); end
        end

        function A = traceDir(~, T)
            %TRACEDIR  Axial direction of each trace, degrees in [0,180).
            A = zeros(0,1);
            if ~isempty(T), A = mod(atan2d(T(:,4)-T(:,2), T(:,3)-T(:,1)), 180); end
        end

        function [D, p, xAt] = ks2(app, a, b)
            %KS2  Two-sample Kolmogorov-Smirnov, without the toolbox.
            %   D is the largest gap between the two empirical CDFs and p the
            %   asymptotic probability of a gap that large between two samples
            %   of one distribution (Press et al., Numerical Recipes 14.3).
            D = NaN; p = NaN; xAt = NaN;
            a = a(:); b = b(:); n1 = numel(a); n2 = numel(b);
            if n1 < 1 || n2 < 1, return, end
            [x, ix] = sort([a; b]);
            isA = [true(n1,1); false(n2,1)]; isA = isA(ix);
            Fa = cumsum(isA)/n1; Fb = cumsum(~isA)/n2;
            last = [diff(x) > 0; true];             % ties: read at the group's end
            gap = abs(Fa - Fb); gap(~last) = 0;
            [D, k] = max(gap); xAt = x(k);
            ne = n1*n2/(n1+n2);
            p = app.ksProb((sqrt(ne) + 0.12 + 0.11/sqrt(ne)) * D);
        end

        function q = ksProb(~, lam)
            %KSPROB  Q_KS(lambda) = 2 sum_j (-1)^(j-1) exp(-2 j^2 lambda^2).
            if lam <= 0, q = 1; return, end
            j = 1:200;
            q = 2*sum((-1).^(j-1) .* exp(-2*j.^2*lam^2));
            q = min(max(q, 0), 1);
        end

        function [V, p] = kuiper2(app, a, b)
            %KUIPER2  Two-sample Kuiper test on angles, in degrees.
            %   V = D+ + D- is the circular form of KS: invariant to where
            %   the circle is cut, which KS on angles is not. Asymptotic p
            %   after Numerical Recipes 14.3 (Stephens 1970).
            V = NaN; p = NaN;
            a = mod(a(:),360); b = mod(b(:),360); n1 = numel(a); n2 = numel(b);
            if n1 < 1 || n2 < 1, return, end
            [x, ix] = sort([a; b]);
            isA = [true(n1,1); false(n2,1)]; isA = isA(ix);
            Fa = cumsum(isA)/n1; Fb = cumsum(~isA)/n2;
            last = [diff(x) > 0; true];
            d = Fa - Fb; d(~last) = 0;
            V = max(max(d), 0) + max(max(-d), 0);
            ne = n1*n2/(n1+n2);
            p = app.kuiperProb((sqrt(ne) + 0.155 + 0.24/sqrt(ne)) * V);
        end

        function q = kuiperProb(~, lam)
            %KUIPERPROB  Q_KP(lambda) = 2 sum_j (4 j^2 lambda^2 - 1) exp(-2 j^2 lambda^2).
            if lam < 0.4, q = 1; return, end       % 1 to seven places below this
            j = 1:200;
            q = 2*sum((4*j.^2*lam^2 - 1) .* exp(-2*j.^2*lam^2));
            q = min(max(q, 0), 1);
        end

        function f = roseFractions(~, A, w, edges)
            %ROSEFRACTIONS  Length-weighted share of each orientation bin.
            %   Weighted by length because a face is read that way: a long
            %   trace is more of the fabric than a short censored fragment.
            nb = numel(edges) - 1;
            f = zeros(1, nb);
            if isempty(A), return, end
            bw = edges(2) - edges(1);
            k = min(max(floor(mod(A(:),180) / bw) + 1, 1), nb);
            f = accumarray(k, w(:), [nb 1])';
            if sum(f) > 0, f = f / sum(f); end
        end

        function t = topology(~, S, tol, area)
            %TOPOLOGY  I / Y / X node counts after Sanderson & Nixon (2015).
            %   Every trace end is a node: I if it ends in intact rock, Y if
            %   it abuts another trace. Every crossing is an X node. Then
            %   lines NL = (NI+NY)/2, branches NB = (NI+3NY+4NX)/2, and
            %   connections per line CL = 2(NY+NX)/NL -- the measure that
            %   separates a network that percolates from one that does not.
            %
            %   Abutment is judged to a tolerance: a digitised end is never
            %   exactly on the line it meets. A generated DFN has no
            %   abutments by construction -- its fractures are placed
            %   independently, so any Y it shows is a chance contact within
            %   the tolerance -- and a mapped face with many more is showing
            %   a limit of the model, not of the fit. Worth seeing, not hiding.
            t = struct('NI',0,'NY',0,'NX',0,'NL',0,'NB',0,'CL',NaN, ...
                       'xPerArea',NaN,'fI',NaN,'fY',NaN,'fX',NaN);
            n = size(S,1);
            if n == 0, return, end
            P1 = S(:,1:2); d = S(:,3:4) - P1;
            len2 = max(sum(d.^2, 2), eps);
            E = [P1; S(:,3:4)]; owner = [1:n, 1:n]';
            isY = false(2*n, 1);
            for k = 1:2*n
                w = E(k,:) - P1;
                s = min(max(sum(w.*d, 2) ./ len2, 0), 1);
                foot = P1 + s.*d;
                dist = hypot(E(k,1)-foot(:,1), E(k,2)-foot(:,2));
                isY(k) = any(dist <= tol & (1:n)' ~= owner(k));
            end
            NY = nnz(isY); NI = 2*n - NY;
            NX = 0;
            for i = 1:n-1
                j  = (i+1:n)';
                r  = d(i,:); s2 = d(j,:);
                den = r(1)*s2(:,2) - r(2)*s2(:,1);
                qp  = P1(j,:) - P1(i,:);
                tt  = (qp(:,1).*s2(:,2) - qp(:,2).*s2(:,1)) ./ den;
                uu  = (qp(:,1)*r(2) - qp(:,2)*r(1)) ./ den;
                % strictly inside both, by more than the abutment tolerance,
                % so a Y is not counted a second time as an X
                ti = tol / sqrt(len2(i)); tj = tol ./ sqrt(len2(j));
                NX = NX + nnz(abs(den) > eps & tt > ti & tt < 1-ti & ...
                              uu > tj & uu < 1-tj);
            end
            t.NI = NI; t.NY = NY; t.NX = NX;
            t.NL = (NI + NY)/2;
            t.NB = (NI + 3*NY + 4*NX)/2;
            if t.NL > 0, t.CL = 2*(NY + NX)/t.NL; end
            if area > 0, t.xPerArea = NX/area; end
            tot = NI + NY + NX;
            if tot > 0, t.fI = NI/tot; t.fY = NY/tot; t.fX = NX/tot; end
        end

        function rows = compareTable(app, c)
            %COMPARETABLE  The scorecard: measure, both values, difference,
            %   and what the difference reads as. Kept as data so a test can
            %   read it and so the window only has to display it.
            pct = @(a,b) sprintf('%+.1f%%', 100*(b-a)/a);
            g   = @(v) sprintf('%.4g', v);
            verdict = @(p) app.pVerdict(p);

            if isnan(c.countZ), zs = '';
            elseif abs(c.countZ) < 1, zs = sprintf('z = %+.1f: within sampling noise', c.countZ);
            elseif abs(c.countZ) < 2, zs = sprintf('z = %+.1f: borderline', c.countZ);
            else, zs = sprintf('z = %+.1f: more than sampling explains', c.countZ);
            end
            tr = c.topR; tg = c.topG;
            ixy = @(t) sprintf('%.0f : %.0f : %.0f', 100*t.fI, 100*t.fY, 100*t.fX);

            rows = { ...
              'INTENSITY', '', '', '', ''
              'traces',              g(c.ref.n),      g(c.gen.n),      pct(c.ref.n,c.gen.n),       zs
              'P21  (length / area)',g(c.ref.P21),    g(c.gen.P21),    pct(c.ref.P21,c.gen.P21),   'the number the fit targets'
              'TRACE LENGTH', '', '', '', ''
              'mean',                g(c.ref.meanL),  g(c.gen.meanL),  pct(c.ref.meanL,c.gen.meanL), ''
              'median',              g(median(c.Lr)), g(median(c.Lg)), pct(median(c.Lr),median(c.Lg)), ''
              'longest',             g(max(c.Lr)),    g(max(c.Lg)),    pct(max(c.Lr),max(c.Lg)),   'censored by the window on both sides'
              'distribution (KS)',   '', '',          sprintf('D = %.3f', c.ksD),  sprintf('p = %.2g: %s', c.ksP, verdict(c.ksP))
              'ORIENTATION', '', '', '', ''
              'mean direction (deg)',sprintf('%.1f',c.dirR), sprintf('%.1f',c.dirG), sprintf('%+.1f deg', c.dirDiff), 'meaningless with more than one set: see the rose'
              'concentration',       sprintf('%.3f',c.concR), sprintf('%.3f',c.concG), '', '1 = one tight set, 0 = no preferred direction'
              'distribution (Kuiper)','', '',         sprintf('V = %.3f', c.kuV),  sprintf('p = %.2g: %s', c.kuP, verdict(c.kuP))
              'TOPOLOGY', '', '', '', ''
              'I : Y : X  (%)',      ixy(tr),         ixy(tg),         '',  'ends free : abutting : crossing'
              'connections per line',g(tr.CL),        g(tg.CL),        '',  'CL = 2(Y+X)/lines; ~3.6 and up percolates'
              'crossings per area',  g(tr.xPerArea),  g(tg.xPerArea),  '',  ''
            };
            rows(cellfun(@(x) isnumeric(x) && isempty(x), rows)) = {''};
        end

        function s = pVerdict(~, p)
            if ~isfinite(p),   s = 'not enough traces to test';
            elseif p >= 0.05,  s = 'no evidence they differ';
            elseif p >= 0.01,  s = 'probably differ';
            else,              s = 'differ';
            end
        end

        function buildCompareWindow(app, c, geo, sec, R, G)
            %BUILDCOMPAREWINDOW  One tab per question, a scorecard first.
            %   Every plot tab carries a "how to read this" line: an axis
            %   called u is not an explanation, and a p-value without a
            %   sentence is a number waiting to be misread.
            f = uifigure('Name','Compare 2D trace maps', 'Tag','ADFNE_GUI_compare', ...
                'Position', app.startupFigurePosition(1120, 780), 'Color', app.BG);
            root = uigridlayout(f, [2 1]);
            root.RowHeight = {22, '1x'}; root.Padding = [8 6 8 8]; root.RowSpacing = 4;
            uilabel(root, 'FontWeight','bold', 'Text', sprintf(['Mapped face vs ' ...
                'generated section   -   section plane dip %g / dipdir %g / offset %g' ...
                '   -   %d mapped traces, %d generated, one window of area %.4g'], ...
                geo.dip, geo.ddir, geo.off, c.ref.n, c.gen.n, c.area));
            tg = uitabgroup(root);
            cm = app.REG_FACE; cg = app.REG_GEN;
            grey = [0.35 0.35 0.35];

            % ---------------------------------------------------- summary
            t = uitab(tg, 'Title','Summary');
            g = uigridlayout(t, [2 1]); g.RowHeight = {'1x', 190};
            tb = uitable(g, 'Data', app.compareTable(c), ...
                'ColumnName', {'measure','mapped','generated','difference','reads as'}, ...
                'ColumnWidth', {160, 90, 90, 120, '1x'}, 'RowName', {}, ...
                'FontName','Consolas');
            hdr = find(cellfun(@(x) ~isempty(x) && all(isstrprop(strrep(x,' ',''),'upper')), tb.Data(:,1)));
            for k = hdr(:)'
                addStyle(tb, uistyle('FontWeight','bold','BackgroundColor',[0.90 0.92 0.95]), 'row', k);
            end
            uitextarea(g, 'Editable','off', 'FontName','Consolas', 'Value', { ...
              'Both maps are measured over the same window: the part of the face the map covers. P21 is a length per unit AREA, so dividing a partial map'
              'by the whole face understates it by exactly the area ratio. Every number here uses that one window, on both sides.'
              ''
              'traces        a count of n has a sampling standard deviation of about sqrt(n). |z| below 2 is what two realisations of ONE network show.'
              'length (KS)   two-sample Kolmogorov-Smirnov: D is the largest gap between the two cumulative curves (Trace length tab). Both maps are cut'
              '              by the same window, so the censoring is the same on both sides and the comparison is fair.'
              'orientation   Kuiper''s test on doubled angles - traces are axial, 179 and 1 are two degrees apart. Unlike a mean direction it works for'
              '              several sets at once. The rose is the picture of it.'
              'topology      Sanderson & Nixon (2015). I = a trace end in intact rock, Y = an end abutting another trace, X = a crossing. A generated'
              '              DFN places every fracture independently, so its Y nodes are chance contacts; a face with many MORE is showing a limit of the model.'
              'p-values      the probability of a gap this large between two samples of ONE distribution. Below 0.05 is normally read as "they differ".'
              '              With fewer than about 30 traces on either side, none of the tests has much to say.'});

            % ------------------------------------------------------- maps
            t = uitab(tg, 'Title','Maps');
            g = uigridlayout(t, [2 2]); g.RowHeight = {'1x', 40};
            lim = [min(sec.box(1),c.win(1)) max(sec.box(2),c.win(2)) ...
                   min(sec.box(3),c.win(3)) max(sec.box(4),c.win(4))];
            app.drawTracePanel(uiaxes(g), R, geo, c.win, lim, ...
                sprintf('mapped:  %d traces,  P21 %.3g', c.ref.n, c.ref.P21), cm);
            app.drawTracePanel(uiaxes(g), G, geo, c.win, lim, ...
                sprintf('generated:  %d traces,  P21 %.3g', c.gen.n, c.gen.P21), cg);
            h = uilabel(g, 'WordWrap','on', 'FontColor',grey, 'Text', ['Face coordinates: ' ...
                'u runs along the strike of the section plane, v up the face, both in domain ' ...
                'units. The blue outline is the face where the plane cuts the domain; the ' ...
                'dashed box is the window the map covers, and everything is measured inside it.']);
            h.Layout.Column = [1 2];

            % ------------------------------------------------ orientation
            t = uitab(tg, 'Title','Orientation');
            g = uigridlayout(t, [2 2]); g.ColumnWidth = {'1x', 370}; g.RowHeight = {'1x', 40};
            ax = uiaxes(g);
            app.drawRose(ax, c.roseEdges, c.roseR, cm, 'mapped');
            app.drawRose(ax, c.roseEdges, c.roseG, cg, 'generated');
            dirs = [c.dirR c.dirG]; cols = [cm; cg];
            for k = 1:2                       % the mean direction of each side
                if isfinite(dirs(k))
                    plot(ax, 1.08*[-cosd(dirs(k)) cosd(dirs(k))], ...
                        1.08*[-sind(dirs(k)) sind(dirs(k))], '-', ...
                        'Color', cols(k,:), 'LineWidth', 2, 'HandleVisibility','off');
                end
            end
            title(ax, 'trace orientation  (axial rose, length-weighted, 10 deg bins)');
            legend(ax, 'Location','southoutside', 'Orientation','horizontal');
            uitextarea(g, 'Editable','off', 'FontName','Consolas', 'Value', { ...
                '                  mapped   generated'
                sprintf('mean direction  %7.1f   %7.1f   deg', c.dirR, c.dirG)
                sprintf('concentration   %7.3f   %7.3f', c.concR, c.concG)
                sprintf('difference in mean direction  %+.1f deg', c.dirDiff)
                ''
                sprintf('Kuiper  V = %.3f    p = %.2g', c.kuV, c.kuP)
                app.pVerdict(c.kuP)
                ''
                'Kuiper''s test compares the whole orientation'
                'distribution, on the circle, and does not'
                'care how many sets there are.'
                ''
                'The mean direction and its concentration'
                'describe ONE set only: two sets 90 degrees'
                'apart give a concentration near 0 and a'
                'mean that points between them. Read the'
                'rose, not the mean.'
                ''
                'Angles are measured in the face from the'
                'strike direction (u) and are axial: a trace'
                'has no head or tail, so the rose is'
                'symmetric and 0 and 180 are the same.'});
            h = uilabel(g, 'WordWrap','on', 'FontColor',grey, 'Text', ['Each wedge is the ' ...
                'share of total trace LENGTH in that 10 degree band, so a long trace counts ' ...
                'for more than a short censored fragment. Where the two colours overlap the ' ...
                'fabric agrees; a wedge in one colour only is a set the other side lacks.']);
            h.Layout.Column = [1 2];

            % ------------------------------------------------ trace length
            t = uitab(tg, 'Title','Trace length');
            g = uigridlayout(t, [2 2]); g.ColumnWidth = {'1x', 330}; g.RowHeight = {'1x', 40};
            ax = uiaxes(g); hold(ax,'on'); grid(ax,'on');
            if ~isempty(c.Lr)
                stairs(ax, [0; sort(c.Lr)], [0; (1:numel(c.Lr))'/numel(c.Lr)], ...
                    '-', 'Color',cm, 'LineWidth',1.8, 'DisplayName','mapped');
            end
            if ~isempty(c.Lg)
                stairs(ax, [0; sort(c.Lg)], [0; (1:numel(c.Lg))'/numel(c.Lg)], ...
                    '-', 'Color',cg, 'LineWidth',1.8, 'DisplayName','generated');
            end
            if isfinite(c.ksAt) && ~isempty(c.Lr) && ~isempty(c.Lg)
                fr = mean(c.Lr <= c.ksAt); fg = mean(c.Lg <= c.ksAt);
                plot(ax, [c.ksAt c.ksAt], [fr fg], ':', 'Color',[0.2 0.2 0.2], ...
                    'LineWidth',2, 'DisplayName', sprintf('KS gap D = %.3f', c.ksD));
            end
            xlabel(ax, 'trace length  (domain units, as cut by the window)');
            ylabel(ax, 'fraction of traces shorter than this');
            title(ax, 'trace-length distribution  (empirical CDF)');
            legend(ax, 'Location','southeast');
            uitextarea(g, 'Editable','off', 'FontName','Consolas', 'Value', { ...
                sprintf('                 mapped   generated')
                sprintf('traces         %7d     %7d', c.ref.n, c.gen.n)
                sprintf('mean length    %7.3g     %7.3g', c.ref.meanL, c.gen.meanL)
                sprintf('median         %7.3g     %7.3g', median(c.Lr), median(c.Lg))
                sprintf('longest        %7.3g     %7.3g', max(c.Lr), max(c.Lg))
                ''
                sprintf('KS  D = %.3f    p = %.2g', c.ksD, c.ksP)
                app.pVerdict(c.ksP)
                ''
                'D is the largest vertical gap between'
                'the two curves (dotted). p is how often'
                'two samples of ONE distribution would'
                'show a gap that large.'
                ''
                'Many size and count combinations give'
                'the same P21 and the same mean; the'
                'shape of this curve is what separates'
                'them. Both sides are censored by the'
                'same window, so the comparison is'
                'fair, but neither is the true size.'});
            h = uilabel(g, 'WordWrap','on', 'FontColor',grey, 'Text', ['Read across: at any ' ...
                'length, the curve gives the fraction of traces shorter than it. Two networks ' ...
                'with the same fabric put the two curves on top of each other; a generated ' ...
                'curve to the LEFT means its traces are shorter than the mapped ones.']);
            h.Layout.Column = [1 2];

            % --------------------------------------------------- topology
            t = uitab(tg, 'Title','Topology');
            g = uigridlayout(t, [2 2]); g.RowHeight = {'1x', 64};
            ax = uiaxes(g);
            app.drawTernary(ax, c.topR, c.topG, cm, cg);
            ax2 = uiaxes(g); hold(ax2,'on'); grid(ax2,'on');
            tr = c.topR; tg2 = c.topG;
            vals = 100*[tr.fI tg2.fI; tr.fY tg2.fY; tr.fX tg2.fX];
            vals(~isfinite(vals)) = 0;
            b = bar(ax2, vals, 'grouped');
            b(1).FaceColor = cm; b(2).FaceColor = cg;
            ax2.XTick = 1:3; ax2.XTickLabel = {'I  (free end)','Y  (abutting)','X  (crossing)'};
            ylabel(ax2, 'share of nodes  (%)');
            title(ax2, sprintf(['nodes:  mapped I %d / Y %d / X %d      generated ' ...
                'I %d / Y %d / X %d'], tr.NI, tr.NY, tr.NX, tg2.NI, tg2.NY, tg2.NX));
            legend(ax2, {'mapped','generated'}, 'Location','northeast');
            h = uilabel(g, 'WordWrap','on', 'FontColor',grey, 'Text', sprintf(['Sanderson ' ...
                '& Nixon (2015): every trace end is an I node (ends in intact rock) or a Y ' ...
                'node (abuts another trace, to within %.3g units here); every crossing is an X ' ...
                'node. Connections per line CL = 2(Y+X)/lines: mapped %.2f, generated %.2f; ' ...
                'networks above about 3.6 percolate. A generated DFN places fractures ' ...
                'independently, so its Y nodes are chance contacts within the tolerance: ' ...
                'a mapped face with many more is showing a limit of the model, not of ' ...
                'the fit.'], c.tol, tr.CL, tg2.CL));
            h.Layout.Column = [1 2];
        end

        function drawTracePanel(~, ax, T, geo, win, lim, ttl, col)
            %DRAWTRACEPANEL  One trace map, framed exactly like the other.
            hold(ax,'on');
            if size(geo.faceUV,1) >= 3
                patch(ax, geo.faceUV(:,1), geo.faceUV(:,2), [1 1 1], ...
                    'FaceColor','none','EdgeColor',[0.10 0.45 0.80],'LineWidth',1.4);
            end
            if ~isempty(T)
                plot(ax, [T(:,1) T(:,3)]', [T(:,2) T(:,4)]', '-', ...
                    'Color', col, 'LineWidth', 1.2);
            end
            plot(ax, win([1 2 2 1 1]), win([3 3 4 4 3]), '--', ...
                'Color',[0.30 0.30 0.30], 'LineWidth',1);
            axis(ax,'equal'); grid(ax,'on');
            pad = 0.04 * max([lim(2)-lim(1), lim(4)-lim(3), eps]);
            xlim(ax, [lim(1)-pad lim(2)+pad]); ylim(ax, [lim(3)-pad lim(4)+pad]);
            xlabel(ax,'u  -  along strike  (domain units)');
            ylabel(ax,'v  -  up the face');
            title(ax, ttl);
        end

        function drawRose(~, ax, edges, frac, col, name)
            %DRAWROSE  Axial rose on an ordinary axes, so it works in a uifigure.
            %   Radius is the bin's share of total length; the mirror half is
            %   drawn too because a trace has no direction, only an axis.
            hold(ax,'on');
            rmax = max([frac(:); eps]);
            if isempty(ax.Children)
                th = linspace(0, 360, 181);
                for r = [0.25 0.5 0.75 1]
                    plot(ax, r*cosd(th), r*sind(th), '-', 'Color',[0.82 0.82 0.82], ...
                        'HandleVisibility','off');
                end
                for a = 0:30:150
                    plot(ax, [-cosd(a) cosd(a)], [-sind(a) sind(a)], '-', ...
                        'Color',[0.85 0.85 0.85], 'HandleVisibility','off');
                    text(ax, 1.16*cosd(a), 1.16*sind(a), sprintf('%d',a), ...
                        'HorizontalAlignment','center', 'Color',[0.4 0.4 0.4], 'FontSize',9);
                    text(ax, -1.16*cosd(a), -1.16*sind(a), sprintf('%d',a+180), ...
                        'HorizontalAlignment','center', 'Color',[0.4 0.4 0.4], 'FontSize',9);
                end
                axis(ax,'equal'); axis(ax,'off');
                xlim(ax,[-1.25 1.25]); ylim(ax,[-1.25 1.25]);
            end
            first = true;
            for k = 1:numel(frac)
                if frac(k) <= 0, continue, end
                r = frac(k) / rmax;
                for half = [0 180]
                    th = linspace(edges(k), edges(k+1), 8) + half;
                    px = [0, r*cosd(th)]; py = [0, r*sind(th)];
                    h = patch(ax, px, py, col, 'FaceAlpha',0.45, 'EdgeColor',col, ...
                        'LineWidth',0.8, 'DisplayName', name);
                    if ~first || half > 0, h.HandleVisibility = 'off'; end
                    first = false;
                end
            end
        end

        function drawTernary(~, ax, tr, tg, cm, cg)
            %DRAWTERNARY  The I-Y-X triangle, with both networks on it.
            hold(ax,'on');
            Y = [0 0]; X = [1 0]; I = [0.5 sqrt(3)/2];
            plot(ax, [Y(1) X(1) I(1) Y(1)], [Y(2) X(2) I(2) Y(2)], '-', ...
                'Color',[0.3 0.3 0.3], 'LineWidth',1.2, 'HandleVisibility','off');
            for q = 0.25:0.25:0.75          % light grid, every 25 %
                a = Y + q*(I-Y); b = X + q*(I-X);   % lines of constant I
                plot(ax, [a(1) b(1)], [a(2) b(2)], ':', 'Color',[0.8 0.8 0.8], 'HandleVisibility','off');
                a = Y + q*(X-Y); b = I + q*(X-I);   % constant X
                plot(ax, [a(1) b(1)], [a(2) b(2)], ':', 'Color',[0.8 0.8 0.8], 'HandleVisibility','off');
                a = X + q*(Y-X); b = I + q*(Y-I);   % constant Y
                plot(ax, [a(1) b(1)], [a(2) b(2)], ':', 'Color',[0.8 0.8 0.8], 'HandleVisibility','off');
            end
            text(ax, I(1), I(2)+0.05, 'I  (isolated ends)', 'HorizontalAlignment','center');
            text(ax, Y(1)-0.02, Y(2)-0.05, 'Y  (abutting)', 'HorizontalAlignment','center');
            text(ax, X(1)+0.02, X(2)-0.05, 'X  (crossing)', 'HorizontalAlignment','center');
            pt = @(t) t.fY*Y + t.fX*X + t.fI*I;
            if isfinite(tr.fI)
                p = pt(tr); plot(ax, p(1), p(2), 'o', 'MarkerSize',11, 'MarkerFaceColor',cm, ...
                    'MarkerEdgeColor','w', 'LineWidth',1.2, 'DisplayName','mapped');
            end
            if isfinite(tg.fI)
                p = pt(tg); plot(ax, p(1), p(2), 's', 'MarkerSize',11, 'MarkerFaceColor',cg, ...
                    'MarkerEdgeColor','w', 'LineWidth',1.2, 'DisplayName','generated');
            end
            axis(ax,'equal'); axis(ax,'off');
            xlim(ax,[-0.15 1.15]); ylim(ax,[-0.12 1.0]);
            title(ax, 'node-type triangle  (Sanderson & Nixon 2015)');
            legend(ax, 'Location','northeast');
        end

        function [mdir, R] = axialMean(~, A)
            %AXIALMEAN  Circular mean of 180-periodic directions, in degrees.
            mdir = NaN; R = NaN;
            if isempty(A), return, end
            C = mean(cosd(2*A)); S = mean(sind(2*A));
            mdir = mod(0.5*atan2d(S, C), 180);
            R = hypot(C, S);
        end

        function captureBaseline(app, sd)
            %CAPTUREBASELINE  Remember the unconditioned model and its inputs.
            %   Only ever called for a model built with conditioning off. That
            %   is what "the original DFN" means: the rock mass before a fit
            %   rewrote the joint sets or conditioning inserted mapped traces.
            %
            %   The inputs are stored alongside the model on purpose. FIT
            %   changes the joint-set table, so putting the model back without
            %   the table it came from would leave the two describing different
            %   rock masses.
            app.Baseline = struct( ...
                'model',  app.Model, ...
                'sets',   app.Sets, ...
                'table',  app.SetTable.Data, ...
                'seed',   sd, ...
                'rgn',    [app.RgnFields.Value], ...
                'shape',  app.ShapeDD.Value, ...
                'facets', app.FacetSpin.Value, ...
                'aspect', [app.AspectField.Value, app.AspectSdField.Value], ...
                'aspectLaw', app.AspectLawDD.Value, ...
                'intensity', app.intensityMode(), ...
                'orientation', app.orientModel(), ...
                'centres',   {{app.centresModel(), app.ClusterField.Value}}, ...
                'terminate', app.TermField.Value, ...
                'axis',   app.AxisDD.Value, ...
                'asep',   app.ASepField.Value, ...
                'dsep',   app.DSepField.Value, ...
                'n',      app.countFractures(), ...
                'when',   char(datetime('now','Format','HH:mm:ss')));
            app.refreshRestoreBtn();
        end

        function refreshRestoreBtn(app)
            %REFRESHRESTOREBTN  Off until there is something to go back to, and
            %   saying exactly what that is. The tooltip carries the numbers
            %   because "restore" is otherwise a promise you cannot check
            %   before pressing it -- and when the baseline was moving on
            %   every generate, this is the line that would have shown it.
            if isempty(app.CondRestoreBtn) || ~isvalid(app.CondRestoreBtn), return, end
            have = isfield(app.Baseline,'model') && ~isempty(app.Baseline.model.fnm);
            app.CondRestoreBtn.Enable = matlab.lang.OnOffSwitchState(have);
            if have
                b = app.Baseline;
                app.CondRestoreBtn.Tooltip = sprintf([ ...
                    'Go back to the DFN generated at %s:' newline ...
                    '    %d fractures, seed %d, %d joint set(s)' newline newline ...
                    'That model was built before any fit or conditioning, and ' ...
                    'this puts back the joint-set table that produced it as ' ...
                    'well -- FIT rewrites that table, so restoring one without ' ...
                    'the other would leave them describing different rock ' ...
                    'masses. Conditioning is switched off and the fit table ' ...
                    'cleared.' newline newline ...
                    'The trace map, the domain and the section plane are left ' ...
                    'alone, so another fit can be tried straight away.'], ...
                    b.when, b.n, b.seed, size(b.table,1));
            else
                app.CondRestoreBtn.Tooltip = ['Nothing to go back to yet. ' ...
                    'Generate once with conditioning off and no fit standing, ' ...
                    'and that DFN becomes the one this returns you to.'];
            end
        end

        function onRestoreBaseline(app)
            %ONRESTOREBASELINE  Back to the DFN before fitting and conditioning.
            if ~isfield(app.Baseline,'model') || isempty(app.Baseline.model.fnm)
                uialert(app.Fig, ['There is no unconditioned model to go back ' ...
                    'to yet. Generate once with "Condition the model on this ' ...
                    'map" unticked, and that becomes the model this returns ' ...
                    'you to.'], 'Nothing to restore');
                return
            end
            b = app.Baseline;
            app.Model = b.model;
            app.Sets  = b.sets;
            for i = 1:6, app.RgnFields(i).Value = b.rgn(i); end
            app.SeedSpin.Value   = b.seed;
            app.ShapeDD.Value    = b.shape;
            app.FacetSpin.Value  = b.facets;
            if isfield(b,'aspect')
                app.AspectField.Value = b.aspect(1); app.AspectSdField.Value = b.aspect(2);
                if isfield(b,'aspectLaw'), app.AspectLawDD.Value = b.aspectLaw; end
                app.AxisDD.Value = b.axis;
            end
            if isfield(b,'intensity'), app.IntensityDD.Value = b.intensity; app.LastIntensity = b.intensity; end
            if isfield(b,'orientation'), app.OrientDD.Value = b.orientation; app.LastOrient = b.orientation; end
            if isfield(b,'centres'), app.CentresDD.Value = b.centres{1}; app.ClusterField.Value = b.centres{2}; end
            if isfield(b,'terminate'), app.TermField.Value = b.terminate; end
            app.ASepField.Value  = b.asep;
            app.DSepField.Value  = b.dsep;
            if ~isempty(app.CondCB), app.CondCB.Value = false; end
            if ~isempty(app.FitTable), app.FitTable.Data = cell(0,5); end
            app.FitApplied = false;     % the fit is undone; the baseline may move again
            app.applyModeToTable();          % writes Sets back into the table
            app.refreshCondUI();
            app.refreshEngineUI();
            app.refreshAnalyses();
            app.refreshPlotTypes();
            app.refreshResultsTable();
            app.syncVars();
            app.describeSection();
            app.refreshStateBar();
            app.renderPlot();
            app.log(sprintf(['Restored the model generated at %s: %d ' ...
                'fractures, seed %d, and the joint sets that produced it. ' ...
                'Conditioning is off and the fit table is cleared.'], ...
                b.when, b.n, b.seed), 'ok');
        end

        function onNewProject(app, skipConfirm)
            %ONNEWPROJECT  Clear everything and start again, without restarting.
            if nargin < 2, skipConfirm = false; end
            if ~skipConfirm
                sel = uiconfirm(app.Fig, ...
                    ['This clears the model, the trace map, every result and ' ...
                     'the joint-set table, and puts the controls back to ' ...
                     'their defaults. None of it can be recovered afterwards.'], ...
                    'Start a new project', ...
                    'Options', {'Discard everything','Cancel'}, ...
                    'DefaultOption', 2, 'CancelOption', 2, 'Icon','warning');
                if ~strcmp(sel,'Discard everything'), return, end
            end

            % model and everything derived from it
            app.Baseline = struct();
            app.FitApplied = false;
            app.Sets = app.defaultSet();
            app.Vars = struct();
            app.resetModel();

            % the rock mass
            defs = [0 1 0 1 0 1];
            for i = 1:6, app.RgnFields(i).Value = defs(i); end
            app.SeedSpin.Value   = 7;
            app.RandSeedCB.Value = false;
            app.ShapeDD.Value    = 'c';
            app.AspectField.Value = 2; app.AspectSdField.Value = 0; app.AxisDD.Value = 'strike';
            app.AspectLawDD.Value = 'logn';
            app.IntensityDD.Value = 'N'; app.LastIntensity = 'N';
            app.OrientDD.Value = 'adfne'; app.LastOrient = 'adfne';
            app.CentresDD.Value = 'poisson'; app.ClusterField.Value = 1.5;
            app.TermField.Value = 0;
            app.FacetSpin.Value  = 24;
            app.ASepField.Value  = 0;
            app.DSepField.Value  = 0;
            app.PresetDD.Value   = app.PresetDD.Items{1};

            % how it is looked at
            app.SecDipF.Value = 90; app.SecDirF.Value = 0; app.SecOffF.Value = 0;
            app.SecClipDD.Value = 'no clipping';
            app.SecShowCB.Value = false;
            app.ModeDD.Value = '3D';

            % the mapped face, and the mapped band
            app.TraceMap = zeros(0,4); app.TraceSid = [];
            app.CondFileName = '';
            app.PlanesLocal = {}; app.PlanesSid = [];
            app.PlanesFileName = ''; app.PlanesFmt = '';
            app.PlaneSets = [30 45 -25 180 -25 0.3 1.0 3.0 0];
            app.BandThkF.Value = 1; app.BandCutCB.Value = false; app.BandClipCB.Value = false;
            app.SizeLawDD.Value = 'exp'; app.onSizeLawChanged();
            app.CondSrcDD.Value = 'syn';
            app.TraceSets = [60 45 25 0.3 1.0 3.0 0];
            app.applyCondTableLayout();
            app.CondCB.Value = false;
            app.CondExclCB.Value = true;
            app.FitTable.Data = cell(0,5);
            app.CondInfo.Value = {'No trace map yet.'};

            % results and what is on screen
            if ~isempty(app.ResTable), app.ResTable.Data = cell(0,2); end
            if ~isempty(app.FlowInfo), app.FlowInfo.Value = {'No flow solution yet.'}; end
            app.PrevPlot = ''; app.PrevPlotTM = '';
            app.onClearPlot();

            app.applyModeToTable();
            app.refreshCondUI();
            app.refreshEngineUI();
            app.refreshAnalyses();
            app.refreshPlotTypes();
            app.refreshResultsTable();
            app.syncVars();
            app.describeInherited();
            app.describeSection();
            app.refreshRestoreBtn();
            app.refreshStateBar();
            app.log('New project: everything cleared.', 'ok');
        end

        %% -------------------------------------- 3D joint planes in a band
        % The 2D route reads a face; this reads a VOLUME: the section plane
        % given a thickness, centred where the section plane is, holding
        % joint planes that were actually mapped -- from a scan, a
        % photogrammetry export, or by hand. It is the better-posed problem.
        % A face cannot tell which way a joint dips, nor separate count from
        % obliquity (README, "Orientation is not fitted"); a plane in 3D
        % carries its dip, its dip direction and its size directly, so only
        % the count still needs the forward model.

        function tf = is3DSource(app)
            tf = ~isempty(app.CondSrcDD) && isvalid(app.CondSrcDD) && ...
                 any(strcmp(app.CondSrcDD.Value, {'syn3','file3'}));
        end

        function nm = previewPlotName(app)
            %PREVIEWPLOTNAME  The plot that shows the field data as it is read.
            if app.is3DSource(), nm = 'Mapped planes'; else, nm = 'Trace map'; end
        end

        function b = bandGeometry(app, rgn)
            %BANDGEOMETRY  The mapped volume: the section plane with a thickness.
            b = app.sectionGeometry(rgn);
            b.thk = 1;
            if ~isempty(app.BandThkF) && isvalid(app.BandThkF), b.thk = app.BandThkF.Value; end
            b.rgn = rgn;
            b.vol = app.bandVolume(b, rgn);
            % the two faces of the slab, for drawing
            b.faceLo = app.planeFace(rgn, b.p0 - (b.thk/2)*b.n, b.e1, b.e2);
            b.faceHi = app.planeFace(rgn, b.p0 + (b.thk/2)*b.n, b.e1, b.e2);
        end

        function f = planeFace(app, rgn, p0, e1, e2)
            %PLANEFACE  Where a plane through p0 cuts the domain box.
            d = norm([rgn(2)-rgn(1), rgn(4)-rgn(3), rgn(6)-rgn(5)]);
            q = p0 + d*[ e1+e2; e1-e2; -e1-e2; -e1+e2 ];
            c = Clip({q}, app.bbx15(rgn, 3));
            if isempty(c), f = zeros(0,3); else, f = c{1}; end
        end

        function v = bandVolume(app, b, rgn)
            %BANDVOLUME  Volume of the slab inside the domain box.
            %   The area of the box's cross-section is a piecewise-quadratic
            %   function of the offset along the normal, so integrating it
            %   across the thickness with composite Simpson on a fine grid is
            %   exact to round-off. A 64^3 point grid was tried first and was
            %   6% out on a band a tenth of the domain wide.
            m = 128;                                   % even
            s = linspace(-b.thk/2, b.thk/2, m + 1);
            a = zeros(1, m + 1);
            for k = 1:m + 1
                f = app.planeFace(rgn, b.p0 + s(k)*b.n, b.e1, b.e2);
                if size(f,1) >= 3, a(k) = abs(polygonArea3d(f)); end
            end
            w = ones(1, m + 1); w(2:2:m) = 4; w(3:2:m-1) = 2;
            v = (b.thk / m) / 3 * sum(w .* a);
        end

        function P = discPoly(~, c, n, d, q)
            %DISCPOLY  A q-gon of diameter d, centred at c, with normal n.
            n = n(:)' / max(norm(n), eps);
            a = [0 0 1]; if abs(dot(a, n)) > 0.9, a = [1 0 0]; end
            e1 = cross(n, a); e1 = e1 / norm(e1);
            e2 = cross(n, e1);
            t = (0:q-1)' * 2*pi/q;
            P = c(:)' + (d/2) * (cos(t) * e1 + sin(t) * e2);
        end

        function Q = clipHalfspace(~, P, p0, n, keepBelow)
            %CLIPHALFSPACE  The part of a convex polygon on one side of a plane:
            %   (P - p0).n <= 0 when keepBelow, >= 0 otherwise.
            Q = zeros(0,3);
            if isempty(P), return, end
            d = (P - p0(:)') * n(:);
            if ~keepBelow, d = -d; end
            tol = 1e-12;
            if all(d <= tol), Q = P; return, end
            if all(d > tol), return, end
            m = size(P,1);
            for i = 1:m
                j = mod(i, m) + 1;
                if d(i) <= tol, Q(end+1,:) = P(i,:); end %#ok<AGROW>
                if (d(i) > tol) ~= (d(j) > tol)
                    w = d(i) / (d(i) - d(j));
                    Q(end+1,:) = P(i,:) + w * (P(j,:) - P(i,:)); %#ok<AGROW>
                end
            end
        end

        function [a, Q] = areaInBand(app, P, b)
            %AREAINBAND  Polygon area inside the slab, and the clipped polygon.
            Q = app.clipHalfspace(P, b.p0 + (b.thk/2)*b.n, b.n, true);
            Q = app.clipHalfspace(Q, b.p0 - (b.thk/2)*b.n, b.n, false);
            a = 0;
            if size(Q,1) >= 3, a = abs(polygonArea3d(Q)); end
        end

        function hit = hitsBand(~, P, b)
            %HITSBAND  Which polygons reach into the slab at all.
            hit = false(numel(P),1);
            for i = 1:numel(P)
                q = P{i}; if isempty(q), continue, end
                sd = (q - b.p0) * b.n(:);
                hit(i) = min(sd) <= b.thk/2 && max(sd) >= -b.thk/2;
            end
        end

        % ------------------------------------------------------- reading
        function onImportField(app)
            %ONIMPORTFIELD  Read a mapped face or a mapped volume.
            %   One button; what is in the file decides which. 4-5 columns
            %   are a trace map (u1 v1 u2 v2 [set]); 3 are polygon corners in
            %   blocks; 6-8 columns or a .mat are joint planes.
            [f, pth] = uigetfile({'*.csv;*.txt;*.dat;*.mat', ...
                'Field data (*.csv, *.txt, *.dat, *.mat)'}, 'Import field data');
            figure(app.Fig);
            if isequal(f,0), return, end
            app.importFieldFile(fullfile(pth, f));
        end

        function importFieldFile(app, fp)
            %IMPORTFIELDFILE  The importer behind the button, callable by path.
            try
                [~, f, e] = fileparts(fp); f = [f e];
                if strcmpi(e, '.mat')
                    [P, sid, fmt] = app.readPlanesMat(fp);
                else
                    M = readmatrix(fp);
                    if size(M,2) >= 4 && size(M,2) <= 5
                        app.importTraceMatrix(M, f); return
                    end
                    [P, sid, fmt] = app.readPlanesText(fp, M);
                end
                if isempty(P)
                    error('ADFNE:NoPlanes', 'No joint planes could be read from %s.', f);
                end
                app.PlanesLocal = P(:); app.PlanesSid = sid(:);
                app.PlanesFileName = f; app.PlanesFmt = fmt;
                app.CondSrcDD.Value = 'file3';
                app.refreshCondUI();
                app.refreshPlotTypes();
                app.describePlanes();
                app.log(sprintf('Imported %d joint planes from %s  (%s).', ...
                    numel(P), f, fmt), 'ok');
            catch ME
                uialert(app.Fig, ME.message, 'Import failed');
            end
        end

        function importTraceMatrix(app, M, f)
            %IMPORTTRACEMATRIX  A 2D trace map already read from file f.
            M = M(all(isfinite(M(:,1:4)),2), :);
            app.TraceMap = M(:,1:4);
            if size(M,2) >= 5, app.TraceSid = M(:,5); else, app.TraceSid = []; end
            app.CondFileName = f;
            app.CondSrcDD.Value = 'file';
            app.refreshCondUI();
            app.refreshPlotTypes();
            app.describeTraceMap();
            app.log(sprintf('Imported %d traces from %s', size(app.TraceMap,1), f), 'ok');
        end

        function [P, sid, fmt] = readPlanesText(app, fp, M)
            %READPLANESTEXT  Joint planes from a text file, three layouts:
            %     3 columns    polygon corners, one polygon per block of rows,
            %                  blocks separated by a blank line
            %     6 columns    xc yc zc dip dipdir size      (size = diameter)
            %     7 columns    xc yc zc nx ny nz radius
            %   With a header row the names decide instead, and an optional
            %   'set' column gives the joint set. Coordinates are local:
            %   axes parallel to the domain's, origin at the band centre.
            sid = []; P = {};
            nc = size(M,2);
            q = 24;
            if ~isempty(app.FacetSpin) && isvalid(app.FacetSpin), q = app.FacetSpin.Value; end
            if nc == 3
                fmt = 'polygon corners';
                txt = fileread(fp);
                blocks = regexp(strtrim(txt), '(\r?\n[ \t]*){2,}', 'split');
                for k = 1:numel(blocks)
                    V = sscanf(regexprep(blocks{k}, '[,;]', ' '), '%f');
                    if isempty(V) || mod(numel(V),3) ~= 0, continue, end
                    V = reshape(V, 3, [])';
                    if size(V,1) >= 3 && all(isfinite(V(:))), P{end+1,1} = V; end %#ok<AGROW>
                end
                return
            end
            names = {};
            try
                opts = detectImportOptions(fp);
                if opts.VariableNamesLine > 0, names = lower(opts.VariableNames); end
            catch, end %#ok<CTCH>
            col = @(nm, k) app.namedColumn(M, names, nm, k);
            hasDip = ~isempty(col({'dip'}, 0));
            hasNrm = ~isempty(col({'nx'}, 0));
            if isempty(names)
                if nc == 6, hasDip = true; elseif nc == 7, hasNrm = true; end
            end
            if ~hasDip && ~hasNrm
                error('ADFNE:PlaneCols', ['Expected 6 columns (xc yc zc dip dipdir ' ...
                    'size), 7 columns (xc yc zc nx ny nz radius), 3 columns of ' ...
                    'polygon corners in blank-line-separated blocks, or a header ' ...
                    'row naming the columns; this file has %d columns%s.'], nc, ...
                    app.namesNote(names));
            end
            M = M(all(isfinite(M(:,1:min(6,nc))),2), :);
            C = [col({'xc','x'},1) col({'yc','y'},2) col({'zc','z'},3)];
            if hasDip
                fmt = 'centre + dip/dipdir + size';
                dip  = col({'dip'},4);
                ddir = col({'dipdir','ddir','dip_dir','dipdirection'},5);
                sz   = col({'size','diameter'},6);
                setk = 7;
            else
                fmt = 'centre + normal + radius';
                N  = [col({'nx'},4) col({'ny'},5) col({'nz'},6)];
                sz = 2 * col({'radius','r'},7);
                setk = 8;
            end
            if size(C,2) ~= 3 || isempty(sz)
                error('ADFNE:PlaneCols', ['The header names do not include the ' ...
                    'columns this layout needs (xc yc zc and size, or radius)%s.'], ...
                    app.namesNote(names));
            end
            if hasDip
                N = zeros(size(M,1),3);
                for i = 1:size(M,1), N(i,:) = app.planeNormal(dip(i), ddir(i)); end
            end
            si = col({'set','sid','setid','set_id','joint_set'}, setk);
            if ~isempty(si) && all(isfinite(si)) && all(si >= 1), sid = round(si(:)); end
            P = cell(size(M,1),1);
            for i = 1:size(M,1)
                P{i} = app.discPoly(C(i,:), N(i,:), sz(i), q);
            end
        end

        function s = namesNote(~, names)
            s = '';
            if ~isempty(names), s = sprintf(' (header: %s)', strjoin(names, ', ')); end
        end

        function v = namedColumn(~, M, names, nm, k)
            %NAMEDCOLUMN  A column by header name when there is a header, and
            %   by position when there is not. Never by position when a
            %   header exists: a file whose seventh column is called 'notes'
            %   must not be read as the joint set.
            v = [];
            if ~isempty(names)
                j = find(ismember(names, nm), 1);
            elseif k >= 1 && k <= size(M,2)
                j = k;
            else
                j = [];
            end
            if ~isempty(j) && j <= size(M,2), v = M(:, j); end
        end

        function [P, sid, fmt] = readPlanesMat(~, fp)
            %READPLANESMAT  A cell array of n-by-3 polygons, plus an optional
            %   set vector named set / sid / setid.
            S = load(fp); fn = fieldnames(S);
            P = {}; sid = []; fmt = 'polygons (.mat)';
            for k = 1:numel(fn)
                v = S.(fn{k});
                if iscell(v) && ~isempty(v) && all(cellfun(@(x) isnumeric(x) && ...
                        size(x,2) == 3 && size(x,1) >= 3, v(:)))
                    P = v(:); break
                end
            end
            if isempty(P)
                error('ADFNE:NoPlanes', ['No cell array of n-by-3 polygon corner ' ...
                    'lists in %s.'], fp);
            end
            for k = 1:numel(fn)
                v = S.(fn{k});
                if isnumeric(v) && isvector(v) && numel(v) == numel(P) && ...
                        any(strcmpi(fn{k}, {'set','sid','setid','sets'}))
                    sid = round(double(v(:)));
                end
            end
        end

        % ------------------------------------------------------- the data
        function [P, sid] = placedPlanes(app, b)
            %PLACEDPLANES  The imported planes in domain coordinates: one
            %   translation, from the band centre.
            P = app.PlanesLocal; sid = app.PlanesSid;
            for i = 1:numel(P), P{i} = P{i} + b.p0; end
            if numel(sid) ~= numel(P), sid = []; end
        end

        function [P, sid] = planesFor(app, b, seed)
            %PLANESFOR  The 3D field data: imported, or drawn from the table.
            %   A synthetic draw is seeded so that FIT, GENERATE and Compare
            %   all see the same planes for the same seed.
            if strcmp(app.CondSrcDD.Value, 'file3')
                [P, sid] = app.placedPlanes(b);
            else
                if nargin < 3 || isempty(seed), seed = app.SeedSpin.Value + 7919; end
                P = app.synthPlanesInBand(app.PlaneSets, b, seed);
                sid = [];
            end
        end

        function P = synthPlanesInBand(app, D, b, seed)
            %SYNTHPLANESINBAND  Joint planes with centres in the slab.
            %   The draws DFN makes -- von Mises dip and dip direction,
            %   truncated-exponential size -- but with the centres put where
            %   a mapped volume would have them, so the table's N is the
            %   number of planes IN THE BAND, not in the whole domain.
            P = {};
            if isempty(D), return, end
            rng(seed);
            q = 24;
            if ~isempty(app.FacetSpin) && isvalid(app.FacetSpin), q = app.FacetSpin.Value; end
            sh = app.shapeSpec();
            diag = norm(b.rgn([2 4 6]) - b.rgn([1 3 5]));
            for i = 1:size(D,1)
                n = round(D(i,1)); if n < 1, continue, end
                if ~app.bandCuts()
                    P = [P; app.synthPlanesBatch(n, D(i,:), app.bandSampler(b), diag, sh, q)]; %#ok<AGROW>
                    continue
                end
                % everything that cuts the band: centres drawn in a slab wide
                % enough for the largest plane to reach in from outside, the
                % planes built, and only those that cut the band kept - n of
                % them - so the bias a scan carries is reproduced exactly and
                % FIT's correction can be checked against the table
                bw = b; bw.thk = b.thk + 2*D(i,8);
                Q = cell(0,1); guard = 0;
                while numel(Q) < n && guard < 50
                    m = max(2*(n - numel(Q)), 8);
                    R = app.synthPlanesBatch(m, D(i,:), app.bandSampler(bw), diag, sh, q);
                    Q = [Q; R(app.hitsBand(R, b))]; %#ok<AGROW>
                    guard = guard + 1;
                end
                P = [P; Q(1:min(n, numel(Q)))]; %#ok<AGROW>
            end
            P = app.applyTermination(P);
            if app.bandClips()
                % a slab scan delivers only what lies inside the band
                for i = 1:numel(P), [~, P{i}] = app.areaInBand(P{i}, b); end
                P = P(cellfun(@(q) size(q,1) >= 3, P));
            end
        end

        function P = synthPlanesBatch(app, n, row, sampler, diag, sh, q)
            %SYNTHPLANESBATCH  n planes of one set row: poles, sizes, centres
            %   from the sampler, the polygon of the chosen shape.
            if ~strcmp(app.orientModel(), 'adfne')
                NP = app.drawPoles(n, row);
            else
                dip  = app.drawAngle(n, row(2), row(3), true);
                ddir = app.drawAngle(n, row(4), row(5), false);
                NP = zeros(n,3);
                for k = 1:n, NP(k,:) = app.planeNormal(dip(k), ddir(k)); end
            end
            sz = app.drawSizes(n, row);
            C  = app.drawCentres(n, sampler, diag);
            m  = size(C,1);
            r  = app.drawAspect(m, sh); spin = 2*pi*rand(m,1);
            P  = cell(m,1);
            for k = 1:m
                if strcmp(sh.kind,'e')
                    P{k} = app.shapePoly(C(k,:), NP(k,:), sz(k), sh.q, r(k), sh.axis, spin(k));
                else
                    P{k} = app.discPoly(C(k,:), NP(k,:), sz(k), q);
                end
            end
        end

        function a = drawAngle(~, n, mu, spread, isDip)
            %DRAWANGLE  DFN's own rules, so a synthetic band is drawn from the
            %   same distributions GENERATE uses: spread > 0 uniform +/- that
            %   much (a dip clamped to 0..90), < 0 von Mises with kappa =
            %   -spread, 0 exactly the mean. For the DIP the von Mises draw
            %   goes through Rand's 'ab',[0,90] branch, the compressed one
            %   DFN.m itself calls -- see dipKappaToTable for what that means.
            if nargin < 5, isDip = false; end
            if spread > 0
                lo = mu - spread; hi = mu + spread;
                if isDip, lo = max(lo, 0); hi = min(hi, 90); end
                a = lo + (hi - lo) * rand(n,1);
            elseif spread < 0
                if isDip
                    a = Rand(n, 'fun','f', 'mu',mu, 'k',-spread, 'ab',[0 90]);
                else
                    a = Rand(n, 'fun','f', 'mu',mu, 'k',-spread);
                end
            else
                a = mu * ones(n,1);
            end
            a = a(:);
        end

        function C = drawInBand(~, n, b)
            %DRAWINBAND  n points uniform in the part of the slab inside the box.
            rgn = b.rgn; lo = rgn([1 3 5]); hi = rgn([2 4 6]);
            C = zeros(n,3); k = 0; tries = 0;
            pad = b.thk;                       % the slab's faces reach past the mid-face
            while k < n && tries < 200
                m = 4*(n-k) + 16;
                u = (b.box(1)-pad) + (b.box(2)-b.box(1)+2*pad)*rand(m,1);
                v = (b.box(3)-pad) + (b.box(4)-b.box(3)+2*pad)*rand(m,1);
                w = b.thk * (rand(m,1) - 0.5);
                p = b.p0 + u.*b.e1 + v.*b.e2 + w.*b.n;
                p = p(all(p >= lo & p <= hi, 2), :);
                t = min(size(p,1), n-k);
                C(k+1:k+t,:) = p(1:t,:); k = k + t; tries = tries + 1;
            end
            C = C(1:k,:);
        end

        function sid = setsForPlanes(app, P, sid, D)
            %SETSFORPLANES  Which joint set each mapped plane belongs to.
            %   The file's own column wins; then a set forced from the
            %   dropdown; else the set whose mean pole is nearest.
            n = numel(P);
            if numel(sid) == n && ~isempty(sid) && all(sid >= 1 & sid <= size(D,1))
                sid = sid(:); return
            end
            forced = 0;
            if ~isempty(app.CondSetDD) && isvalid(app.CondSetDD), forced = app.CondSetDD.Value; end
            if forced >= 1 && forced <= size(D,1), sid = forced * ones(n,1); return, end
            Np = zeros(size(D,1),3);
            for i = 1:size(D,1), Np(i,:) = app.planeNormal(D(i,2), D(i,4)); end
            sid = zeros(n,1);
            for k = 1:n
                [~, sid(k)] = max(abs(Np * app.polyNormal(P{k})'));
            end
        end

        function describePlanes(app, P, b)
            %DESCRIBEPLANES  What the mapped volume holds, in the info box.
            if nargin < 3 || isempty(b), b = app.bandGeometry(app.liveRgn()); end
            if nargin < 2 || isempty(P)
                P = {};
                if app.is3DSource(), try, P = app.planesFor(b); catch, end, end %#ok<CTCH>
            end
            if isempty(P), app.CondInfo.Value = {'No joint planes yet.'}; return, end
            sz = Size3D(P);
            [ds, dds] = app.orient(P);
            sd = cellfun(@(q) (mean(q,1) - b.p0) * b.n(:), P);
            inBand = abs(sd) <= b.thk/2;
            ain = 0;
            for i = 1:numel(P), ain = ain + app.areaInBand(P{i}, b); end
            app.CondInfo.Value = { ...
                sprintf('planes        : %d   (%d with centre in the band)', numel(P), nnz(inBand))
                sprintf('size    min   : %.4g', min(sz))
                sprintf('        mean  : %.4g', mean(sz))
                sprintf('        max   : %.4g', max(sz))
                sprintf('dip     mean  : %.4g deg     dipdir mean : %.4g deg', ...
                        mean(rad2deg(ds)), mod(rad2deg(atan2(mean(sin(dds)), mean(cos(dds)))), 360))
                sprintf('off plane     : %.4g .. %.4g   (band is +/- %.4g)', min(sd), max(sd), b.thk/2)
                sprintf('P32 in band   : %.4g   (area %.4g / volume %.4g)', ...
                        ain / max(b.vol, eps), ain, b.vol)};
            if nnz(inBand) < numel(P) && ~app.bandCuts()
                app.CondInfo.Value = [app.CondInfo.Value; {sprintf(['%d plane centres ' ...
                    'lie outside the band: thicken it, or check the coordinates.'], ...
                    numel(P) - nnz(inBand))}];
            end
            if app.bandClips()
                app.CondInfo.Value = [app.CondInfo.Value; {sprintf(['clipped at faces: %d   ' ...
                    '(sizes are lower bounds; FIT corrects by simulated sampling)'], ...
                    nnz(app.censoredAtFaces(P, b)))}];
            end
        end

        % ------------------------------------------------------- fitting
        function sid = clusterPoles(app, P, degTol)
            %CLUSTERPOLES  Group planes into sets by pole orientation.
            %   Axial k-means seeded by a leader pass: any pole more than
            %   degTol from every existing set axis starts a new set, then a
            %   few rounds of reassign-and-recompute. Deterministic, and
            %   good enough to give FIT a starting table; the fit then
            %   measures each set's mean and scatter properly.
            n = numel(P);
            N = zeros(n,3);
            for i = 1:n, N(i,:) = app.polyNormal(P{i}); end
            ct = cosd(degTol);
            axes_ = zeros(0,3);
            sid = zeros(n,1);
            for i = 1:n
                if isempty(axes_), axes_ = N(i,:); sid(i) = 1; continue, end
                [c, j] = max(abs(axes_ * N(i,:)'));
                if c >= ct, sid(i) = j;
                else, axes_(end+1,:) = N(i,:); sid(i) = size(axes_,1); end %#ok<AGROW>
            end
            for it = 1:6
                k = size(axes_,1);
                for j = 1:k
                    M = N(sid == j, :);
                    if isempty(M), continue, end
                    [V, E] = eig(M' * M); [~, m] = max(diag(E));
                    axes_(j,:) = V(:,m)';
                end
                [~, new] = max(abs(N * axes_'), [], 2);
                if isequal(new, sid), break, end
                sid = new;
            end
            % drop sets that lost all their planes, keep ids 1..k dense
            [~, ~, sid] = unique(sid);
        end

        function [mu, kappa] = vonMisesFit(app, a, w)
            %VONMISESFIT  Circular mean and concentration of angles in degrees,
            %   optionally weighted.
            if nargin < 3 || isempty(w), w = ones(size(a)); end
            w = w(:) / sum(w); a = a(:);
            C = sum(w .* cosd(a)); S = sum(w .* sind(a));
            mu = mod(atan2d(S, C), 360);
            kappa = app.kappaFromR(hypot(C, S));
        end

        function tf = bandCuts(app)
            %BANDCUTS  Whether the mapped planes are those that cut the band.
            tf = ~isempty(app.BandCutCB) && isvalid(app.BandCutCB) && app.BandCutCB.Value;
        end

        function tf = bandClips(app)
            %BANDCLIPS  Whether the cutting planes are also clipped at the faces.
            tf = app.bandCuts() && ~isempty(app.BandClipCB) && isvalid(app.BandClipCB) && app.BandClipCB.Value;
        end

        function c = censoredAtFaces(app, P, b)
            %CENSOREDATFACES  Which polygons have a corner on a band face - the
            %   ones a slab scan cut off, whose size is a lower bound. Nothing
            %   is censored unless the planes are declared clipped.
            n = numel(P); c = false(n,1);
            if ~app.bandClips(), return, end
            tol = 1e-3 * b.thk;
            for i = 1:n
                sd = abs((P{i} - b.p0) * b.n(:));
                c(i) = any(sd >= b.thk/2 - tol);
            end
        end

        function h = bandExtents(~, P, b)
            %BANDEXTENTS  Each polygon's extent across the band.
            n = numel(P); h = zeros(n,1);
            for i = 1:n
                sd = (P{i} - b.p0) * b.n(:);
                h(i) = max(sd) - min(sd);
            end
        end

        function [Lmin, Lmean, Lmax, Lp] = sizeParams(app, x, w)
            %SIZEPARAMS  The table's size columns for one set from sizes x
            %   with weights w: the observed range is the truncation, and the
            %   law is read off the sizes as they are.
            x = x(:); w = w(:);
            law = app.sizeLaw();
            Lmin = min(x); Lmax = max(x);
            mS = app.wmean(x, w); sS = app.wstd(x, w);
            switch law
                    case 'logn'
                        % mean and sd of what was measured; the truncation
                        % is the observed range, so the two nearly agree
                        Lmean = mS; Lp = sS;
                    case 'pow'
                        Lmean = mS; Lp = app.powerLawExponent(x, Lmin, Lmax, w);
                    case 'unif'
                        Lmean = mS; Lp = 0;
                    case 'norm'
                        Lmean = mS; Lp = sS;
                    case 'weib'
                        % method of moments on the shape: the coefficient
                        % of variation fixes k on its own
                        cv = sS / max(mS, 1e-12);
                        g = @(k) sqrt(max(gamma(1+2/k)/gamma(1+1/k)^2 - 1, 0)) - cv;
                        try, kw = fzero(g, [0.2 50]); catch, kw = 2; end %#ok<CTCH>
                        Lmean = mS; Lp = kw;
                    case 'gam'
                        Lmean = mS; Lp = (mS / max(sS, 1e-12))^2;
                    case 'boot'
                        Lmean = mS; Lp = 0;         % the data are the law
                    otherwise
                        Lmean = app.truncExpMu(mS, Lmin, Lmax); Lp = 0;
            end
        end

        function [row, sc] = clipFit(app, row, b, obsMean)
            %CLIPFIT  The set row at which planes drawn from it, cut by the
            %   band and clipped at its faces, show the same weighted mean
            %   size as the mapped clipped planes. Simulated sampling, as the
            %   2D fit matches mean trace length: the clip is a sampling
            %   operation, so it is reproduced rather than inverted - it
            %   works whether one plane is clipped or every one, and under
            %   any size law. One bisection on the size scale; the law's
            %   spread or shape parameter is left as read off the clipped
            %   sizes, because the spread of clipped sizes says little about
            %   it (the clip sets most of that spread) and matching it is
            %   unstable. The log names it as weakly determined.
            if strcmp(app.sizeLaw(), 'pow')
                % the power law's scale is its range; the exponent is the
                % one free parameter, and a clipped sample reads it far too
                % flat, so it is the exponent that is matched
                g = @(al) app.clippedSizeStats([row(1:8), al], b) - obsMean;
                row(9) = app.bisect(g, 1.05, 6, 0.01 * obsMean, 16); sc = 1;
                return
            end
            g = @(f) app.clippedSizeStats(app.scaleRow(row, f), b) - obsMean;
            sc = app.bisect(g, 0.25, 8, 0.01 * obsMean, 16);
            row = app.scaleRow(row, sc);
        end

        function t = clipNote(app, n, sc, lp)
            %CLIPNOTE  What the fit did about clipped planes, for the log.
            switch app.sizeLaw()
                case 'pow'
                    t = sprintf(' (%d clipped at the faces: exponent %.3g by simulated sampling)', n, lp);
                case {'exp','unif','boot'}
                    t = sprintf(' (%d clipped at the faces: size scale %.3gx by simulated sampling)', n, sc);
                otherwise
                    t = sprintf([' (%d clipped at the faces: size scale %.3gx by simulated sampling; ' ...
                        '%s read off the clipped sizes, weakly determined)'], n, sc, ...
                        strtrim(app.lpHeader()));
            end
        end

        function [x, bracketed] = bisect(~, g, lo, hi, tol, iters)
            %BISECT  A root of g in [lo, hi], or the closer end if there is
            %   no sign change; stops when |g| < tol. Regula falsi with the
            %   Illinois step: the forward statistics are smooth in their
            %   parameter (common random numbers), so a secant through the
            %   bracket lands within tolerance in three to five evaluations
            %   where halving took fourteen, and each evaluation is a whole
            %   network. The bracket still shrinks every step, so it cannot
            %   do worse than bisection.
            flo = g(lo); fhi = g(hi);
            bracketed = flo * fhi <= 0;
            if ~bracketed
                if abs(flo) < abs(fhi), x = lo; else, x = hi; end
                return
            end
            if abs(flo) < tol, x = lo; return, end
            if abs(fhi) < tol, x = hi; return, end
            x = 0.5 * (lo + hi); side = 0;
            for it = 1:iters
                x = (lo * fhi - hi * flo) / (fhi - flo);
                if ~isfinite(x) || x <= lo || x >= hi, x = 0.5 * (lo + hi); end
                fm = g(x);
                if abs(fm) < tol, break, end
                if flo * fm < 0
                    hi = x; fhi = fm;
                    if side == -1, flo = flo / 2; end     % Illinois: unstick the far end
                    side = -1;
                else
                    lo = x; flo = fm;
                    if side == 1, fhi = fhi / 2; end
                    side = 1;
                end
            end
        end

        function row = scaleRow(~, row, sc)
            %SCALEROW  The mean and largest size of a set row scaled by sc.
            %   L min stays: it is the smallest complete plane, a true size,
            %   or the smallest sliver, which no scale makes meaningful.
            row(7:8) = row(7:8) * sc;
        end

        function [m, sd] = clippedSizeStats(app, row, b)
            %CLIPPEDSIZESTATS  Weighted mean and sd of the lengths of planes
            %   drawn from one row as a clipped band scan records them, fixed
            %   seed. The statistic is each clipped polygon's LENGTH - its
            %   largest corner-to-corner extent, which for a plane cut to a
            %   strip is the chord along the band and grows with the size of
            %   the plane it came from, where an area-based size grows only
            %   with its square root and barely moves.
            row(1) = 1200;
            P = app.synthPlanesInBand(row, b, 4242);
            if isempty(P), m = 0; sd = 0; return, end
            x = app.polyLengths(P); w = app.bandWeights(P, b);
            m = app.wmean(x, w); sd = app.wstd(x, w);
        end

        function L = polyLengths(~, P)
            %POLYLENGTHS  The largest corner-to-corner extent of each polygon.
            n = numel(P); L = zeros(n,1);
            for i = 1:n
                q = P{i}; if size(q,1) < 2, continue, end
                d = sqrt(max(sum((permute(q,[1 3 2]) - permute(q,[3 1 2])).^2, 3), [], 'all'));
                L(i) = d;
            end
        end

        function w = bandWeights(app, P, b, h)
            %BANDWEIGHTS  Horvitz-Thompson weights for planes recorded as
            %   everything that cuts the band: a plane of extent h across the
            %   band is cut with probability proportional to (t + h), so it
            %   counts 1 / (t + h). All ones when the planes are those whose
            %   centres lie in the band, which carries no such bias. The
            %   extents are measured unless given (a clipped plane's is
            %   estimated from its expected true size).
            n = numel(P); w = ones(n,1);
            if ~app.bandCuts(), return, end
            if nargin < 4 || isempty(h), h = app.bandExtents(P, b); end
            w = 1 ./ (b.thk + h(:));
            w = w / mean(w);
        end

        function m = wmean(~, x, w)
            w = w(:) / sum(w); m = sum(w .* x(:));
        end

        function sd = wstd(app, x, w)
            m = app.wmean(x, w); w = w(:) / sum(w);
            sd = sqrt(max(sum(w .* (x(:) - m).^2) / max(1 - sum(w.^2), 1e-12), 0));
        end

        function kappa = kappaFromR(~, R)
            %KAPPAFROMR  A^-1(R): von Mises kappa from the mean resultant
            %   length (Best & Fisher 1981, as in Fisher 1993 p. 88).
            if R < 0.53,     kappa = 2*R + R^3 + 5*R^5/6;
            elseif R < 0.85, kappa = -0.4 + 1.39*R + 0.43/(1 - R);
            else,            kappa = 1 / max(R^3 - 4*R^2 + 3*R, 1e-12);
            end
            kappa = min(max(kappa, 0), 1e5);
        end

        function R = besselRatio(~, kappa)
            %BESSELRATIO  A(kappa) = I1(kappa)/I0(kappa), the mean resultant
            %   length of a von Mises distribution. Scaled Bessel functions so
            %   a large kappa does not overflow.
            kappa = max(kappa, 0);
            R = besseli(1, kappa, 1) ./ besseli(0, kappa, 1);
        end

        function kTab = dipKappaToTable(app, kEff)
            %DIPKAPPATOTABLE  The dDip value that makes DFN reproduce a
            %   measured dip scatter.
            %
            %   ADFNE's DFN does not draw the dip as a plain von Mises. For a
            %   negative dDip it draws von Mises(180, kappa) on the full
            %   circle and COMPRESSES it by a quarter into 0..90 (Rand.m, the
            %   'ab == 90' branch), then shifts it onto the mean dip. So the
            %   same kappa gives a dip spread four times tighter than a dip-
            %   direction spread: dDip = -30 is about +/-2.6 degrees, dDDir =
            %   -30 about +/-10.5. The 3D fit measures the dip scatter as it
            %   is - a plain von Mises kappa - and wrote that number straight
            %   into the table, so DFN then reproduced a scatter sixteen times
            %   too concentrated. This converts at the boundary.
            %
            %   Exact through the circular variance: compressing by 1/4
            %   divides the angular variance by 16, so with R = A(kappa) the
            %   mean resultant length, A(kTab)^(1/16) = A(kEff), hence
            %   kTab = A^-1( A(kEff)^16 ). For large kappa this is kEff/16.
            kTab = app.kappaFromR(app.besselRatio(kEff)^16);
        end

        function kEff = dipKappaFromTable(app, kTab)
            %DIPKAPPAFROMTABLE  The plain von Mises kappa a table dDip acts as.
            kEff = app.kappaFromR(app.besselRatio(kTab)^(1/16));
        end

        function [dip, ddir] = poleAngles(app, P)
            %POLEANGLES  Dip and dip direction of each plane, all poles signed
            %   into one hemisphere -- the one the group's mean axis points
            %   into -- so a near-vertical set does not split into two
            %   antipodal clusters and hand the dip-direction mean to noise.
            n = numel(P);
            N = zeros(n,3);
            for i = 1:n, N(i,:) = app.polyNormal(P{i}); end
            [V, E] = eig(N' * N);
            [~, k] = max(diag(E)); m = V(:,k)';
            if m(3) < 0, m = -m; end
            flip = (N * m') < 0;
            N(flip,:) = -N(flip,:);
            dip  = acosd(max(-1, min(1, N(:,3))));
            ddir = mod(atan2d(N(:,2), N(:,1)), 360);
            % A plane of dip d towards ddir is also a plane of dip -d towards
            % ddir + 180, and DFN's draws use both: a set at dip 25 with some
            % scatter puts a few planes past horizontal, and those come back
            % here with the opposite dip direction. Left alone, two or three
            % of them 180 degrees off drag the dip-direction concentration
            % from 20 down to 6. Describe each plane the way that puts its
            % dip direction nearest the group's, negative dip and all.
            for pass = 1:2
                mu = atan2d(mean(sind(ddir)), mean(cosd(ddir)));
                dd = abs(mod(ddir - mu + 180, 360) - 180);
                da = abs(mod(ddir + 180 - mu + 180, 360) - 180);
                alt = da < dd;
                if ~any(alt), break, end
                dip(alt)  = -dip(alt);
                ddir(alt) = mod(ddir(alt) + 180, 360);
            end
        end

        function al = powerLawExponent(~, L, a, b, w)
            %POWERLAWEXPONENT  Maximum-likelihood exponent of a power law
            %   truncated to [a, b]: density c L^-al. The log-likelihood is
            %   -al sum(ln L) - n ln( integral of L^-al over [a,b] ), and one
            %   bounded search finds its maximum. Optionally weighted.
            L = L(:); n = numel(L); a = max(a, 1e-12);
            if b <= a || n < 2, al = 2.5; return, end
            if nargin < 5 || isempty(w), w = ones(n,1); end
            w = n * w(:) / sum(w);
            S = sum(w .* log(L));
            Z = @(al) (b^(1-al) - a^(1-al)) / (1-al);
            nll = @(al) al*S + n*log(max(Z(al), 1e-300));
            al = fminbnd(nll, 1.01, 8);
        end

        function mu = truncExpMu(~, target, a, b)
            %TRUNCEXPMU  The exponential mean whose truncation to [a,b] has
            %   the given mean -- which is what DFN's L mean is, and why the
            %   observed mean is not it.
            if b <= a, mu = a; return, end
            m = @(mu) mu + (a*exp(-a/mu) - b*exp(-b/mu)) / max(exp(-a/mu) - exp(-b/mu), 1e-300);
            if target <= a * 1.001, mu = max(a, 1e-3*b); return, end
            if target >= (a+b)/2 * 0.999, mu = 1e3 * b; return, end
            lo = log(1e-3*b); hi = log(1e3*b);
            for it = 1:60
                mid = 0.5*(lo+hi);
                if m(exp(mid)) < target, lo = mid; else, hi = mid; end
            end
            mu = exp(0.5*(lo+hi));
        end

        function p32 = bandP32(app, Di, rgn, b, seeds)
            %BANDP32  P32 inside the band that one set row produces, averaged
            %   over fixed seeds -- the forward model the count is fitted on.
            a = zeros(numel(seeds),1);
            for k = 1:numel(seeds)
                P = app.trialNetwork(Di, rgn, seeds(k));
                for i = 1:numel(P), a(k) = a(k) + app.areaInBand(P{i}, b); end
            end
            p32 = mean(a) / max(b.vol, eps);
        end

        function fitFromPlanes(app)
            %FITFROMPLANES  Joint-set parameters from planes mapped in a band.
            %   Orientation and size are read straight off the planes; only
            %   the count goes through the forward model -- P32 inside the
            %   band, matched with fixed seeds, exactly as the 2D fitter
            %   matches P21 on the face.
            %
            %   The setting is the one Rogers et al. (2017) describe for
            %   photogrammetric surveys: mapped planes of known orientation
            %   go into the model as they are, embedded in a stochastic
            %   network fitted to them. P32 is Dershowitz & Herda (1992).
            %   Circular means and von Mises kappas are Fisher (1993), with
            %   the A^-1 approximation of Best & Fisher (1981) -- the same
            %   family ADFNE draws from (Best & Fisher 1979). References in
            %   README.md.
            rgn = [app.RgnFields.Value];
            app.harvestCondTable();
            if strcmp(app.CondSrcDD.Value,'syn3') && isempty(app.PlaneSets)
                app.guideNoSynthetic('plane statistics'); return
            end
            b = app.bandGeometry(rgn);
            [P, sid] = app.planesFor(b);
            if isempty(P)
                uialert(app.Fig, ['No joint planes to fit to. Import a file, or set ' ...
                    'Source to synthetic 3D planes and fill in the table.'], 'No planes');
                return
            end
            cl = app.busy('Fitting: joint sets from the mapped planes…', true, 'fit'); %#ok<NASGU>
            try
                app.harvestSets(); D0 = app.countsFor(app.Sets, rgn);
                built = '';
                if isempty(D0)
                    % No table to adjust: build one from the planes. A 3D
                    % plane carries its orientation, so the data can say how
                    % many sets there are - from the file's set column when
                    % it has one, else by clustering the poles. (A 2D trace
                    % map cannot do this; see onFitSets.)
                    if ~isempty(sid) && numel(sid) == numel(P)
                        [~, ~, sid] = unique(sid(:));     % ids 1..k, no gaps
                        k = max(sid); built = sprintf('%d set(s) from the file''s set column', k);
                    else
                        sid = app.clusterPoles(P, 25);
                        k = max(sid); built = sprintf('%d set(s) by clustering the poles (25 deg)', k);
                    end
                    D0 = repmat(app.defaultSet(), k, 1);
                    D0(:,3) = -20; D0(:,5) = -20;           % scatter, until measured
                    for jj = 1:k
                        [D0(jj,3), D0(jj,5)] = app.fisherToScatter(app.orientModel(), D0(jj,2), 20);
                    end
                end
                D = D0;
                sid = app.setsForPlanes(P, sid, D0);
                sz = Size3D(P);
                % a synthetic band was built with the model's own shape, so
                % its mean-ray diameters are converted back to the long-axis
                % diameters the generator takes; imported planes are taken as
                % they come - their size is whatever the file says it is
                if strcmp(app.CondSrcDD.Value,'syn3'), sz = sz / app.shapeSizeRatio(); end
                % planes recorded as everything that cuts the band are a
                % biased sample of the rock mass: weight them back
                W = app.bandWeights(P, b);
                % planes clipped at the faces carry censored sizes: flagged
                % here, matched by simulated sampling below
                C = app.censoredAtFaces(P, b);
                % the aspect ratio, from each plane's own principal axes:
                % one law for the whole table, so it is fitted over all the
                % planes at once, and only when the shape is elongated. A
                % clipped polygon has no shape of its own and is left out.
                if strcmp(app.shapeSpec().kind, 'e') && ~strcmp(app.AspectLawDD.Value, 'boot') && any(~C)
                    ar = cellfun(@(q) app.polyAspect(q), P(~C));
                    app.AspectField.Value   = max(1, app.wmean(ar, W(~C)));
                    app.AspectSdField.Value = app.wstd(ar, W(~C));
                end
                ain = zeros(numel(P),1);
                for i = 1:numel(P), ain(i) = app.areaInBand(P{i}, b); end
                seeds = 1000 + (1:5);
                rep = {};
                for i = 1:size(D0,1)
                    f = find(sid == i); n = numel(f);
                    if n == 0
                        rep{end+1} = sprintf('set %d: no mapped planes, left as it was', i); %#ok<AGROW>
                        continue
                    end
                    % orientation: each angle on its own, which is how DFN
                    % draws them. Below three planes the scatter is not
                    % estimable and the table's own value stands.
                    [dip, ddir] = app.poleAngles(P(f));
                    wf = W(f);
                    [D(i,2), kd]  = app.vonMisesFit(dip, wf);
                    [D(i,4), kdd] = app.vonMisesFit(ddir, wf);
                    if D(i,2) > 90, D(i,2) = 180 - D(i,2); D(i,4) = mod(D(i,4) + 180, 360); end
                    if strcmp(app.orientModel(), 'boot')
                        D(i,3) = 0; D(i,5) = 0;     % the poles themselves are the law
                    elseif strcmp(app.orientModel(), 'fisher')
                        % one kappa from the poles themselves, signed into the
                        % mean hemisphere: the maximum-likelihood Fisher fit
                        NN = zeros(n,3);
                        for k = 1:n, NN(k,:) = app.polyNormal(P{f(k)}); end
                        mm = app.meanAxis(P(f)); NN(NN*mm' < 0, :) = -NN(NN*mm' < 0, :);
                        if n >= 3, D(i,3) = app.fisherKappa(NN, wf); end
                        D(i,5) = 0;
                    elseif any(strcmp(app.orientModel(), {'bvn','kent','bingham'})) && n >= 3
                        % the poles' scatter in the tangent plane at the mean:
                        % its 2 x 2 covariance carries every two-parameter model
                        NN = zeros(n,3);
                        for k = 1:n, NN(k,:) = app.polyNormal(P{f(k)}); end
                        mm = app.meanAxis(P(f)); NN(NN*mm' < 0, :) = -NN(NN*mm' < 0, :);
                        [D(i,3), D(i,5)] = app.tangentScatter(app.orientModel(), NN, D(i,2), D(i,4), wf);
                    elseif n >= 3
                        % kd is the dip scatter as measured; the table's dDip
                        % is in DFN's compressed convention, see dipKappaToTable
                        D(i,3) = -app.dipKappaToTable(kd); D(i,5) = -kdd;
                    end
                    % size: the observed range is the truncation, and the
                    % law is read off the sizes (weighted, if the band cuts)
                    [D(i,6), D(i,7), D(i,8), D(i,9)] = app.sizeParams(sz(f), wf);
                    mS = app.wmean(sz(f), wf);
                    csc = 1;
                    if any(C(f))
                        % clipped planes are smaller than the planes they came
                        % from: find the row at which planes drawn from it and
                        % clipped the same way show the mean size and spread
                        % that were measured. A clipped sliver says nothing
                        % about the smallest plane, so L min is the smallest
                        % complete plane when there is one.
                        if any(~C(f)), D(i,6) = min(sz(f(~C(f)))); end
                        D(i,8) = max(D(i,8), D(i,6) * 1.01);
                        [D(i,:), csc] = app.clipFit(D(i,:), b, app.wmean(app.polyLengths(P(f)), wf));
                    end
                    % count: match P32 inside the band, forward, fixed seeds.
                    % Every fracture adds its own expected area to the band,
                    % so P32 is linear in N and one reference trial gives the
                    % count outright; termination and clustered centres bend
                    % the line a little, and only then is the answer checked
                    % with a second trial and rescaled once.
                    tgt = sum(ain(f)) / max(b.vol, eps);
                    Nref = 1500; Di = D(i,:); Di(1) = Nref;
                    got = app.bandP32(Di, rgn, b, seeds);
                    if got > 0, N = max(1, round(Nref * tgt / got));
                    else,       N = max(1, round(D0(i,1)));
                    end
                    if app.termination() > 0 || ~strcmp(app.centresModel(), 'poisson')
                        Di(1) = N; got = app.bandP32(Di, rgn, b, seeds);
                        if got > 0 && abs(tgt / got - 1) > 0.03, N = max(1, round(N * tgt / got)); end
                    end
                    D(i,1) = N;
                    rep{end+1} = sprintf(['set %d: %d planes -> dip %.1f / dipdir %.1f, ' ...
                        'kappa %.0f / %.0f, size %.3g .. %.3g (mean %.3g), N %d for ' ...
                        'P32 %.4g in the band%s%s'], i, n, D(i,2), D(i,4), abs(D(i,3)), ...
                        abs(D(i,5)), D(i,6), D(i,8), mS, N, tgt, ...
                        app.iff(app.bandCuts(), ' (weighted for band-cutting sampling)', ''), ...
                        app.iff(any(C(f)), app.clipNote(nnz(C(f)), csc, D(i,9)), '')); %#ok<AGROW>
                end
                D = app.intensitiesFor(D, rgn); D0 = app.intensitiesFor(D0, rgn);   % back to what the table holds
                app.Sets = D;
                app.applyModeToTable();
                app.refreshCondUI();
                app.showFitPreview(D0, D);
                app.FitLbl.Text = ['Fitted joint sets  (written to the Model tab; ' ...
                    'orientation fitted too - a 3D plane carries it)'];
                if ~isempty(built)
                    rep = [{sprintf('table was empty: built %s', built)}, rep];
                    app.log(sprintf(['The joint-set table was empty, so FIT built it from ' ...
                        'the planes: %s. Check the rows on the Model tab.'], built), 'ok');
                end
                app.describePlanes(P, b);
                app.CondInfo.Value = [app.CondInfo.Value; [{''; '--- fit to these planes ---'}; rep(:)]];
                app.FitApplied = true;
                app.refreshRestoreBtn();
                app.log(sprintf('Fit from %d mapped planes.  %s', numel(P), strjoin(rep, ';  ')), 'ok');
            catch ME
                app.log(['Fit failed: ' ME.message],'error');
                uialert(app.Fig, ME.message, 'Fit failed');
            end
        end

        % ------------------------------------------------------- comparing
        function onComparePlanes(app)
            %ONCOMPAREPLANES  The planes you mapped against what the model
            %   put in the same band: count and P32 against sqrt(n), size by
            %   KS, dip by KS, dip direction by Kuiper, and the angle between
            %   the two mean poles.
            if isempty(app.Model.fnm)
                uialert(app.Fig, ['Generate a model first: there is nothing in ' ...
                    'the band to compare the planes against.'], 'Nothing to compare');
                return
            end
            b = app.bandGeometry(app.Model.rgn);
            cl = app.busy('comparing joint planes...', false, 'compare'); %#ok<NASGU>
            try
                R = app.planesFor(b);
            catch ME
                uialert(app.Fig, ME.message, 'Could not build the joint planes'); return
            end
            if isempty(R)
                uialert(app.Fig, ['No joint planes to compare against. Import a ' ...
                    'file, or fill in the synthetic 3D table.'], 'No planes');
                return
            end
            G = app.modelPlanesInBand(app.Model.fnm, b);
            c = app.comparePlanesStats(R, G, b);
            app.buildComparePlanesWindow(c, b, R, G);
            app.log(sprintf(['Compared joint planes: mapped %d / P32 %.4g, model %d ' ...
                'in the band (%s) / P32 %.4g; size KS p %.2g, dip KS p %.2g, dipdir ' ...
                'Kuiper p %.2g.'], c.nR, c.p32R, c.nG, c.sampling, c.p32G, c.ksSizeP, c.ksDipP, ...
                c.kuDdirP), 'ok');
        end

        function G = modelPlanesInBand(app, P, b)
            %MODELPLANESINBAND  The model fractures a band scan would have
            %   recorded, selected the way the mapped planes were: centres in
            %   the band, every plane that cuts it, or those cut and clipped
            %   at the faces. Comparing clipped mapped planes with full model
            %   fractures - or centred mapped planes with every cutting one -
            %   would report a size gap on a model that is right.
            if app.bandCuts()
                G = P(app.hitsBand(P, b));
                if app.bandClips()
                    for i = 1:numel(G), [~, G{i}] = app.areaInBand(G{i}, b); end
                    G = G(cellfun(@(q) size(q,1) >= 3, G));
                end
            else
                sd = cellfun(@(q) (mean(q,1) - b.p0) * b.n(:), P);
                G = P(abs(sd) <= b.thk/2);
            end
            G = G(:);
        end

        function t = bandSamplingNote(app)
            %BANDSAMPLINGNOTE  How the band's planes are taken, in words.
            if ~app.bandCuts(),    t = 'centres in the band';
            elseif app.bandClips(), t = 'cut by the band, clipped at the faces';
            else,                   t = 'every plane that cuts the band';
            end
        end

        function c = comparePlanesStats(app, R, G, b)
            %COMPAREPLANESSTATS  Every number the plane comparison shows.
            c = struct('vol', b.vol, 'thk', b.thk);
            c.sampling = app.bandSamplingNote();
            c.nR = numel(R); c.nG = numel(G);
            c.aR = 0; for i = 1:numel(R), c.aR = c.aR + app.areaInBand(R{i}, b); end
            c.aG = 0; for i = 1:numel(G), c.aG = c.aG + app.areaInBand(G{i}, b); end
            c.p32R = c.aR / max(b.vol, eps); c.p32G = c.aG / max(b.vol, eps);
            c.countZ = NaN; if c.nR > 0, c.countZ = (c.nG - c.nR) / sqrt(c.nR); end
            c.szR = zeros(0,1); c.szG = zeros(0,1);
            if ~isempty(R), c.szR = Size3D(R); end
            if ~isempty(G), c.szG = Size3D(G); end
            [c.ksSizeD, c.ksSizeP, c.ksSizeAt] = app.ks2(c.szR, c.szG);
            c.dipR = zeros(0,1); c.ddirR = c.dipR; c.dipG = c.dipR; c.ddirG = c.dipR;
            if ~isempty(R), [d1, d2] = app.orient(R); c.dipR = rad2deg(d1(:)); c.ddirR = rad2deg(d2(:)); end
            if ~isempty(G), [d1, d2] = app.orient(G); c.dipG = rad2deg(d1(:)); c.ddirG = rad2deg(d2(:)); end
            [c.ksDipD, c.ksDipP] = app.ks2(c.dipR, c.dipG);
            [c.kuDdirV, c.kuDdirP] = app.kuiper2(c.ddirR, c.ddirG);
            c.meanPoleR = app.meanAxis(R); c.meanPoleG = app.meanAxis(G);
            c.poleDiff = NaN;
            if ~any(isnan(c.meanPoleR)) && ~any(isnan(c.meanPoleG))
                c.poleDiff = acosd(min(1, abs(dot(c.meanPoleR, c.meanPoleG))));
            end
        end

        function m = meanAxis(app, P)
            %MEANAXIS  The axial mean of a set of poles: the principal
            %   eigenvector of the orientation tensor, signed upward.
            m = [NaN NaN NaN];
            if isempty(P), return, end
            N = zeros(numel(P),3);
            for i = 1:numel(P)
                q = P{i};
                if size(q,1) == 1, N(i,:) = q / max(norm(q), eps);   % already a pole
                else, N(i,:) = app.polyNormal(q); end
            end
            [V, E] = eig(N' * N);
            [~, k] = max(diag(E)); m = V(:,k)';
            if m(3) < 0, m = -m; end
        end

        function rows = comparePlanesTable(app, c)
            pct = @(a,b) sprintf('%+.1f%%', 100*(b-a)/a);
            g = @(v) sprintf('%.4g', v);
            v = @(p) app.pVerdict(p);
            if isnan(c.countZ), zs = '';
            elseif abs(c.countZ) < 1, zs = sprintf('z = %+.1f: within sampling noise', c.countZ);
            elseif abs(c.countZ) < 2, zs = sprintf('z = %+.1f: borderline', c.countZ);
            else, zs = sprintf('z = %+.1f: more than sampling explains', c.countZ);
            end
            rows = { ...
              'INTENSITY  (in the band)', '', '', '', ''
              'planes / fractures',   g(c.nR),       g(c.nG),       pct(c.nR, c.nG),      zs
              'area in the band',     g(c.aR),       g(c.aG),       pct(c.aR, c.aG),      ''
              'P32  (area / volume)', g(c.p32R),     g(c.p32G),     pct(c.p32R, c.p32G),  'the number the fit targets'
              'SIZE', '', '', '', ''
              'mean',                 g(mean(c.szR)), g(mean(c.szG)), pct(mean(c.szR), mean(c.szG)), ''
              'median',               g(median(c.szR)), g(median(c.szG)), pct(median(c.szR), median(c.szG)), ''
              'largest',              g(max(c.szR)), g(max(c.szG)),  pct(max(c.szR), max(c.szG)), 'model fractures are clipped by the domain'
              'distribution (KS)',    '', '',          sprintf('D = %.3f', c.ksSizeD), sprintf('p = %.2g: %s', c.ksSizeP, v(c.ksSizeP))
              'ORIENTATION', '', '', '', ''
              'mean dip (deg)',       sprintf('%.1f', mean(c.dipR)), sprintf('%.1f', mean(c.dipG)), sprintf('%+.1f deg', mean(c.dipG)-mean(c.dipR)), ''
              'angle between mean poles', '', '',      sprintf('%.1f deg', c.poleDiff), 'axial mean of all poles, each side'
              'dip distribution (KS)', '', '',         sprintf('D = %.3f', c.ksDipD), sprintf('p = %.2g: %s', c.ksDipP, v(c.ksDipP))
              'dip direction (Kuiper)', '', '',        sprintf('V = %.3f', c.kuDdirV), sprintf('p = %.2g: %s', c.kuDdirP, v(c.kuDdirP))
            };
            rows(cellfun(@(x) isnumeric(x) && isempty(x), rows)) = {''};
        end

        function buildComparePlanesWindow(app, c, b, R, G)
            f = uifigure('Name','Compare 3D joint planes', 'Tag','ADFNE_GUI_compare', ...
                'Position', app.startupFigurePosition(1120, 780), 'Color', app.BG);
            root = uigridlayout(f, [2 1]);
            root.RowHeight = {22, '1x'}; root.Padding = [8 6 8 8]; root.RowSpacing = 4;
            uilabel(root, 'FontWeight','bold', 'Text', sprintf(['Mapped joint planes vs ' ...
                'the model in the same band   -   band dip %g / dipdir %g / offset %g, ' ...
                '%.3g thick, volume %.4g   -   %d mapped, %d in the model'], ...
                b.dip, b.ddir, b.off, b.thk, b.vol, c.nR, c.nG));
            tg = uitabgroup(root);
            cm = app.REG_FACE; cg = app.REG_GEN; grey = [0.35 0.35 0.35];

            % ---------------------------------------------------- summary
            t = uitab(tg, 'Title','Summary');
            g = uigridlayout(t, [2 1]); g.RowHeight = {'1x', 170};
            tb = uitable(g, 'Data', app.comparePlanesTable(c), ...
                'ColumnName', {'measure','mapped','model','difference','reads as'}, ...
                'ColumnWidth', {190, 90, 90, 120, '1x'}, 'RowName', {}, 'FontName','Consolas');
            hdr = find(all(cellfun(@isempty, tb.Data(:,2:5)), 2));   % label-only rows
            for k = hdr(:)'
                addStyle(tb, uistyle('FontWeight','bold','BackgroundColor',[0.90 0.92 0.95]), 'row', k);
            end
            uitextarea(g, 'Editable','off', 'FontName','Consolas', 'Value', { ...
              'Both sides are measured inside the same band: the section plane given a thickness, centred on it. "Model" is the fractures of the'
              'generated network a scan of that band would have recorded, taken the way the mapped planes were (the two boxes on the band row):'
              sprintf('%-14s%s', '  this time:', c.sampling)
              'with conditioning on, the mapped planes are among them and the two sides should agree.'
              ''
              'count / P32   a count of n has a sampling standard deviation of about sqrt(n). |z| below 2 is what two realisations of ONE network show.'
              '              P32 is fracture area per unit volume, the quantity the generator is calibrated on, so it is the number FIT targets.'
              'size (KS)     two-sample Kolmogorov-Smirnov on the size of every plane (its diameter). Model fractures are clipped by the domain box.'
              'orientation   a 3D plane carries its own dip and dip direction, so both are compared directly - something a 2D face cannot do. Dip is a'
              '              linear quantity (KS); dip direction goes round a circle (Kuiper). The angle between the mean poles is the one-number summary.'
              'p-values      the probability of a gap this large between two samples of ONE distribution. Below 0.05 is normally read as "they differ".'
              '              With fewer than about 30 planes on either side, none of the tests has much to say.'});

            % --------------------------------------------------- stereonet
            t = uitab(tg, 'Title','Stereonet');
            g = uigridlayout(t, [2 2]); g.ColumnWidth = {'1x', 370}; g.RowHeight = {'1x', 40};
            ax = uiaxes(g); hold(ax,'on');
            tt = linspace(0, 2*pi, 300);
            plot(ax, cos(tt), sin(tt), 'k-', 'LineWidth',1, 'HandleVisibility','off');
            for r = [0.25 0.5 0.75]
                plot(ax, r*cos(tt), r*sin(tt), ':', 'Color',[0.8 0.8 0.8], 'HandleVisibility','off');
            end
            plot(ax, [-1 1], [0 0], ':', 'Color',[0.8 0.8 0.8], 'HandleVisibility','off');
            plot(ax, [0 0], [-1 1], ':', 'Color',[0.8 0.8 0.8], 'HandleVisibility','off');
            app.stereoPoles(ax, c.dipG, c.ddirG, cg, 'model, in the band', 's', 6);
            app.stereoPoles(ax, c.dipR, c.ddirR, cm, 'mapped', 'o', 7);
            text(ax, 1.10, 0, '+X', 'HorizontalAlignment','center', 'FontWeight','bold', 'Color',grey);
            text(ax, 0, 1.10, '+Y', 'HorizontalAlignment','center', 'FontWeight','bold', 'Color',grey);
            axis(ax,'equal'); axis(ax,'off'); xlim(ax,[-1.2 1.2]); ylim(ax,[-1.2 1.2]);
            title(ax, 'fracture poles   (equal-area, lower hemisphere, model XY frame)');
            legend(ax, 'Location','southoutside', 'Orientation','horizontal');
            uitextarea(g, 'Editable','off', 'FontName','Consolas', 'Value', { ...
                '                    mapped     model'
                sprintf('planes           %7d   %7d', c.nR, c.nG)
                sprintf('mean dip         %7.1f   %7.1f   deg', mean(c.dipR), mean(c.dipG))
                sprintf('angle between mean poles   %.1f deg', c.poleDiff)
                ''
                sprintf('dip        KS  D = %.3f   p = %.2g', c.ksDipD, c.ksDipP)
                ['           ' app.pVerdict(c.ksDipP)]
                sprintf('dip dir.   Kuiper V = %.3f   p = %.2g', c.kuDdirV, c.kuDdirP)
                ['           ' app.pVerdict(c.kuDdirP)]
                ''
                'A pole is the normal to a plane, plotted'
                'where it pierces the lower hemisphere: a'
                'horizontal plane sits at the centre, a'
                'vertical one on the rim, and the pole''s'
                'azimuth is the dip direction. Tight'
                'clusters are joint sets. Where the two'
                'colours sit together the sets agree in'
                'orientation; a cluster in one colour only'
                'is a set the other side lacks.'});
            h = uilabel(g, 'WordWrap','on', 'FontColor',grey, 'Text', ['Angles are in the ' ...
                'model frame: +X to the right, +Y up, dip direction anticlockwise from +X. ' ...
                'This is the comparison a 2D face cannot make: on a face a joint dipping into ' ...
                'the rock and one dipping out of it leave the same trace.']);
            h.Layout.Column = [1 2];

            % -------------------------------------------------------- size
            t = uitab(tg, 'Title','Size');
            g = uigridlayout(t, [2 2]); g.ColumnWidth = {'1x', 330}; g.RowHeight = {'1x', 40};
            ax = uiaxes(g); hold(ax,'on'); grid(ax,'on');
            if ~isempty(c.szR)
                stairs(ax, [0; sort(c.szR)], [0; (1:numel(c.szR))'/numel(c.szR)], '-', ...
                    'Color',cm, 'LineWidth',1.8, 'DisplayName','mapped');
            end
            if ~isempty(c.szG)
                stairs(ax, [0; sort(c.szG)], [0; (1:numel(c.szG))'/numel(c.szG)], '-', ...
                    'Color',cg, 'LineWidth',1.8, 'DisplayName','model, in the band');
            end
            if isfinite(c.ksSizeAt) && ~isempty(c.szR) && ~isempty(c.szG)
                fr = mean(c.szR <= c.ksSizeAt); fg = mean(c.szG <= c.ksSizeAt);
                plot(ax, [c.ksSizeAt c.ksSizeAt], [fr fg], ':', 'Color',[0.2 0.2 0.2], ...
                    'LineWidth',2, 'DisplayName', sprintf('KS gap D = %.3f', c.ksSizeD));
            end
            xlabel(ax, 'fracture size  (diameter, domain units)');
            ylabel(ax, 'fraction of planes smaller than this');
            title(ax, 'size distribution  (empirical CDF)');
            legend(ax, 'Location','southeast');
            uitextarea(g, 'Editable','off', 'FontName','Consolas', 'Value', { ...
                '                 mapped   model'
                sprintf('planes         %7d   %7d', c.nR, c.nG)
                sprintf('mean size      %7.3g   %7.3g', mean(c.szR), mean(c.szG))
                sprintf('median         %7.3g   %7.3g', median(c.szR), median(c.szG))
                sprintf('largest        %7.3g   %7.3g', max(c.szR), max(c.szG))
                ''
                sprintf('KS  D = %.3f    p = %.2g', c.ksSizeD, c.ksSizeP)
                app.pVerdict(c.ksSizeP)
                ''
                'D is the largest vertical gap between'
                'the two curves (dotted). p is how often'
                'two samples of ONE distribution would'
                'show a gap that large.'
                ''
                'Size is the plane''s diameter. Model'
                'fractures are clipped by the domain'
                'box, so the largest of them can come'
                'out smaller than they were drawn.'});
            h = uilabel(g, 'WordWrap','on', 'FontColor',grey, 'Text', ['Read across: at any ' ...
                'size, the curve gives the fraction of planes smaller than it. A model curve to ' ...
                'the LEFT means its fractures are smaller than the mapped ones.']);
            h.Layout.Column = [1 2];

            % ---------------------------------------------------- the band
            t = uitab(tg, 'Title','Band');
            g = uigridlayout(t, [2 1]); g.RowHeight = {'1x', 40};
            ax = uiaxes(g); hold(ax,'on');
            rgn = b.rgn;
            app.drawBandScene(ax, b, R, G, cm, cg);
            xlabel(ax,'X'); ylabel(ax,'Y'); zlabel(ax,'Z');
            axis(ax,'equal'); xlim(ax, rgn(1:2)); ylim(ax, rgn(3:4)); zlim(ax, rgn(5:6));
            view(ax, [-35 20]); grid(ax,'on');
            title(ax, sprintf('the band: %d mapped planes (amber) and %d model fractures reaching into it (blue)', c.nR, c.nG));
            legend(ax, 'Location','northeast');
            try, ax.Interactions = [rotateInteraction zoomInteraction]; catch, end %#ok<CTCH>
            uilabel(g, 'WordWrap','on', 'FontColor',grey, 'Text', ['Drag to rotate. The ' ...
                'two translucent faces are the band; the mapped planes are placed with their ' ...
                'local origin at its centre. Model fractures that do not reach into the band ' ...
                'are not drawn.']);
        end

        function stereoPoles(~, ax, dip, ddir, col, name, mk, ms)
            if isempty(dip), return, end
            ds = deg2rad(dip(:)); dds = deg2rad(ddir(:));
            pl = pi/2 - ds; tr = mod(dds + pi, 2*pi);
            Rr = sqrt(2) * sin((pi/2 - pl)/2);
            plot(ax, Rr.*cos(tr), Rr.*sin(tr), mk, 'MarkerSize',ms, 'MarkerFaceColor',col, ...
                'MarkerEdgeColor','w', 'LineWidth',0.5, 'DisplayName',name);
        end

        function drawBandScene(app, ax, b, R, G, cm, cg)
            %DRAWBANDSCENE  Domain box, the slab's two faces, both plane sets.
            rgn = b.rgn;
            [x1,x2,y1,y2,z1,z2] = deal(rgn(1),rgn(2),rgn(3),rgn(4),rgn(5),rgn(6));
            V = [x1 y1 z1; x2 y1 z1; x2 y2 z1; x1 y2 z1; x1 y1 z2; x2 y1 z2; x2 y2 z2; x1 y2 z2];
            E = [1 2;2 3;3 4;4 1;5 6;6 7;7 8;8 5;1 5;2 6;3 7;4 8];
            for k = 1:size(E,1)
                plot3(ax, V(E(k,:),1), V(E(k,:),2), V(E(k,:),3), '-', ...
                    'Color',[0.45 0.45 0.45], 'HandleVisibility','off');
            end
            for F = {b.faceLo, b.faceHi}
                if size(F{1},1) >= 3
                    patch(ax, 'XData',F{1}(:,1), 'YData',F{1}(:,2), 'ZData',F{1}(:,3), ...
                        'FaceColor',[0.10 0.45 0.80], 'FaceAlpha',0.12, ...
                        'EdgeColor',[0.06 0.30 0.60], 'LineWidth',1.2, 'HandleVisibility','off');
                end
            end
            app.patchPolysOn(ax, G, cg, 0.35, 'model, in the band');
            app.patchPolysOn(ax, R, cm, 0.75, 'mapped planes');
        end

        function patchPolysOn(~, ax, plys, rgb, alpha, name)
            %PATCHPOLYSON  patchPolys, but on a given axes and with a legend name.
            n = numel(plys);
            if n == 0, return, end
            nv = cellfun(@(q) size(q,1), plys);
            plys = plys(nv >= 3); nv = nv(nv >= 3);
            m = numel(plys); if m == 0, return, end
            Vx = zeros(sum(nv),3); Fc = nan(m, max(nv)); at = 0;
            for i = 1:m
                Vx(at+1:at+nv(i),:) = plys{i};
                Fc(i,1:nv(i)) = at+1:at+nv(i); at = at + nv(i);
            end
            patch(ax, 'Faces',Fc, 'Vertices',Vx, 'FaceColor',rgb, 'FaceAlpha',alpha, ...
                'EdgeColor',rgb*0.6, 'LineWidth',0.6, 'DisplayName',name);
        end

        function describeTraceMap(app, T)
            %DESCRIBETRACEMAP  Summarise a map; the stored one unless told.
            %   Show traces passes the map it actually drew, so a synthetic
            %   source no longer reports "No trace map yet" underneath a
            %   picture of sixty traces -- TraceMap holds imported maps only
            %   until GENERATE fills it.
            if nargin < 2, T = app.TraceMap; end
            if isempty(T)
                app.CondInfo.Value = {'No trace map yet.'}; return
            end
            L = sqrt(sum((T(:,3:4)-T(:,1:2)).^2, 2));
            a = mod(atan2d(T(:,4)-T(:,2), T(:,3)-T(:,1)), 180);
            app.CondInfo.Value = { ...
                sprintf('traces        : %d', size(T,1))
                sprintf('length  min   : %.4g', min(L))
                sprintf('        mean  : %.4g', mean(L))
                sprintf('        max   : %.4g', max(L))
                sprintf('extent u      : %.4g .. %.4g', min(T(:,[1 3]),[],'all'), ...
                                                        max(T(:,[1 3]),[],'all'))
                sprintf('extent v      : %.4g .. %.4g', min(T(:,[2 4]),[],'all'), ...
                                                        max(T(:,[2 4]),[],'all'))
                sprintf('direction mean: %.4g deg (in-plane)', mean(a))};
        end

        % ---------------------------------------------------------- Flow tab
        function buildFlowTab(app)
            tab = uitab(app.TabGroup, 'Title','Flow');
            g = uigridlayout(tab,[6 1]);
            g.RowHeight = {22, app.panelH(3), 22, app.panelH(2)+34, 34, '1x'};
            g.Scrollable = 'on';
            g.RowSpacing = 6; g.Padding = [10 10 10 10];

            uilabel(g,'Text','Boundary conditions','FontWeight','bold', ...
                'Tooltip',['Which faces of the domain drive the flow, and ' ...
                 'what happens on the rest. Head is imposed on the inlet and ' ...
                 'outlet faces; the solver finds the flux that results.']);

            bp = uipanel(g,'BackgroundColor',app.PANEL,'Tooltip', ...
                ['Head is imposed on two opposite faces of the domain and ' ...
                 'the solver finds the flux across them. Flow runs on the ' ...
                 'connected backbone only: if inlet and outlet are not in ' ...
                 'the same cluster there is nothing to solve, and the app ' ...
                 'says so rather than returning a zero.']);
            bg = uigridlayout(bp,[3 4]); bg.Padding=[8 4 8 4];
            bg.ColumnWidth = {76,135,70,110};
            bg.RowHeight = repmat({app.ROW_H},1,3); bg.RowSpacing = 4;
            bg.RowSpacing = 4; bg.ColumnSpacing = 4;

            tp = ['Which pair of opposite faces the head difference is ' ...
                  'applied across. The effective permeability is reported ' ...
                  'along this direction, so run all three to see anisotropy.'];
            uilabel(bg,'Text','Flow direction','Tooltip',tp);
            app.FlowDirDD = uidropdown(bg,'Items',{'X  (left to right)', ...
                'Y  (front to back)','Z  (bottom to top)'}, ...
                'ItemsData',{'x','y','z'},'Value','x','Tooltip',tp);
            tp = ['What happens on the four faces that are not inlet or ' ...
                  'outlet. No flow seals them, which is the usual choice for ' ...
                  'a permeability measurement. Linear head imposes a ' ...
                  'straight-line gradient along them instead.'];
            uilabel(bg,'Text','Other sides','Tooltip',tp);
            app.FlowBCDD = uidropdown(bg,'Items', ...
                {'no flow','linear head'},'ItemsData',{'noflow','linear'}, ...
                'Tooltip',tp);

            tp = ['Hydraulic head on the inlet and outlet faces. Only the ' ...
                  'difference matters: the reported permeability divides it ' ...
                  'out, so 1 and 0 are as good as any other pair.'];
            uilabel(bg,'Text','Inlet head','Tooltip',tp);
            app.FlowPinF  = uieditfield(bg,'numeric','Value',1,'Tooltip',tp);
            uilabel(bg,'Text','Outlet head','Tooltip',tp);
            app.FlowPoutF = uieditfield(bg,'numeric','Value',0,'Tooltip',tp);

            tp = ['How fractures are turned into a pipe network. Centre runs ' ...
                  'pipes from each fracture centre to its intersections - ' ...
                  'fast, and the usual choice. Triangulation meshes the ' ...
                  'intersections instead: finer, much slower, 3D only.'];
            uilabel(bg,'Text','Pipe method','Tooltip',tp);
            app.FlowMtdDD = uidropdown(bg,'Items',{'centre','triangulation'}, ...
                'ItemsData',{'cnt','tri'},'Value','cnt','Tooltip',tp);
            uilabel(bg,'Text','');
            uilabel(bg,'Text','');

            uilabel(g,'Text','Hydraulics','FontWeight','bold','Tooltip', ...
                ['The fluid and the opening it flows through. These set the ' ...
                 'absolute scale of the answer; the geometry sets its shape.']);

            hp = uipanel(g,'BackgroundColor',app.PANEL,'Tooltip', ...
                ['Conductance follows the cubic law, so it goes as the CUBE ' ...
                 'of aperture: doubling the aperture multiplies the flux by ' ...
                 'eight. Aperture is the single most sensitive number here.']);
            % Stacked, not side by side: "Kin. visc. (m2/s)" and a standard
            % well will not sit beside "Aperture (m)" and its own in 432 px,
            % and the value was being cut to "1.787e-(" at the panel edge.
            hg = uigridlayout(hp,[3 2]); hg.Padding=[8 4 8 4];
            hg.ColumnWidth = {110, app.FLD_W};
            % 30, not 16: the note wraps to two lines in a 218 px column, and
            % at one line's height the second was simply cut off.
            hg.RowHeight = [repmat({app.ROW_H},1,2), {30}]; hg.RowSpacing = 4;
            tp = ['Hydraulic aperture, in metres, applied to every ' ...
                  'fracture. Conductance goes as aperture cubed, so this ' ...
                  'drives the result more than anything else on the tab: ' ...
                  '1e-4 m is a typical joint, 1e-3 an open one.'];
            uilabel(hg,'Text','Aperture (m)','Tooltip',tp);
            app.FlowApF = uieditfield(hg,'numeric','Value',1e-4, ...
                'Limits',[1e-9 1],'ValueDisplayFormat','%.3g','Tooltip',tp);
            tp = ['Kinematic viscosity of the fluid, m2/s. The default is ' ...
                  'water at about 0 degrees C; water at 20 degrees is ' ...
                  'roughly 1.0e-6.'];
            uilabel(hg,'Text','Kin. visc. (m2/s)','Tooltip',tp);
            app.FlowKvF = uieditfield(hg,'numeric','Value',1.787e-6, ...
                'Limits',[1e-12 1],'ValueDisplayFormat','%.4g','Tooltip',tp);
            lb = uilabel(hg,'Text', ...
                'cubic law: pipe conductance from aperture and length', ...
                'FontSize',11,'FontColor',[.45 .45 .45],'WordWrap','on');
            lb.Layout.Row = 3; lb.Layout.Column = [1 2];

            r = uigridlayout(g,[1 2]); r.ColumnWidth = {'1x',150};
            r.Padding=[0 0 0 0];
            app.FlowRunBtn = uibutton(r,'Text','SOLVE FLOW','FontWeight','bold', ...
                'BackgroundColor',app.ACCENT,'FontColor',[1 1 1],'Tooltip', ...
                ['Pipes, then backbone, then graph, then solve. Cost grows ' ...
                 'as the square of the fracture count and so does memory, so ' ...
                 'expect minutes past a few hundred fractures - the log ' ...
                 'warns before it starts.'], ...
                'ButtonPushedFcn',@(s,e) app.onRunFlow());
            uibutton(r,'Text','Clear solution','Tooltip', ...
                ['Throw away the flow solution and its plots. The model and ' ...
                 'the other analyses are untouched.'], ...
                'ButtonPushedFcn',@(s,e) app.onClearFlow());

            app.FlowInfo = uitextarea(g,'Editable','off','FontName','Consolas', ...
                'FontSize',11,'Value',{'No flow solution yet.'},'Tooltip', ...
                ['The solution. Read "balance" first: it is ' ...
                 '|Qin-Qout|/Qin and should be near zero - mass has to be ' ...
                 'conserved, so anything else means the answer is not to be ' ...
                 'trusted. K effective is Qout*L/(A*dH), the permeability ' ...
                 'along the flow direction.']);
        end

        function onClearFlow(app)
            R = app.Model.results;
            for f = {'flow','flowQin','flowQout','flowK','flowBalance'}
                if isfield(R,f{1}), R = rmfield(R,f{1}); end
            end
            app.Model.results = R;
            app.FlowInfo.Value = {'No flow solution yet.'};
            app.refreshResultsTable(); app.refreshPlotTypes();
            app.log('Flow solution cleared.');
        end

        function onRunFlow(app)
            app.refreshStateBar();
            if isempty(app.Model.fnm)
                uialert(app.Fig,'Generate a network first.','No network'); return
            end
            cl = app.busy('Flow: pipes -> backbone -> graph -> solve…', true, 'flow'); %#ok<NASGU>
            try
                m    = app.Model;
                is3  = iscell(m.fnm);
                dirc = app.FlowDirDD.Value;
                if ~is3 && strcmp(dirc,'z')
                    error('ADFNE:Flow2DZ','A 2D network has no Z direction.');
                end
                lin  = strcmp(app.FlowBCDD.Value,'linear');
                [be, span, area] = app.boundaryElements(m.rgn, is3, dirc, lin);
                mtd = app.FlowMtdDD.Value;
                if ~is3, mtd = 'cnt'; end       % triangulation is a 3D method

                % Pipe -> Intersect is O(n^2) in fractures and Graph grows
                % struct arrays element by element. Past a few hundred
                % fractures this stops being slow and starts being unusable -
                % a 900-fracture model took MATLAB down with an access
                % violation - so say so before spending the time.
                nfrac = numel(m.fnm);
                if nfrac > 400
                    app.log(sprintf(['Flow on %d fractures: intersection cost ' ...
                        'grows as n^2 and memory with it. Expect minutes, and ' ...
                        'consider a smaller domain or fewer fractures.'], nfrac), 'warn');
                end
                t0  = tic;
                dfn = Pipe(be, m.fnm, mtd);
                if ~isfield(dfn,'pip') || ~dfn.pip.Percolate
                    app.FlowInfo.Value = { ...
                        'NOT PERCOLATING', '', ...
                        'Inlet and outlet are not in the same cluster, so there is', ...
                        'no connected path across the domain and nothing to solve.', '', ...
                        'Raise fracture density (N), lengths, or set orientations', ...
                        'closer to the flow direction, then generate again.'};
                    app.log('Flow: network does not percolate between the chosen faces.','warn');
                    return
                end
                dfn = Backbone(dfn);
                if ~isfield(dfn,'bbn')
                    error('ADFNE:NoBackbone', ...
                        'Percolating, but no backbone survived the isolation sweep.');
                end
                ap  = app.FlowApF.Value;
                dfn = Graph(dfn, @(x) ap);
                bv  = [app.FlowPinF.Value, app.FlowPoutF.Value];
                if lin, bv = [bv, nan(1, size(be,1)-2)]; end
                % Solve's linear system is often badly scaled - pipe
                % conductance goes as length, and pipe lengths in a real
                % network span orders of magnitude - so MATLAB warns about a
                % tiny RCOND. That is a warning about SCALING, not about rank:
                % on a network that fired it every time, K still tracked the
                % cubic law to 8.0000 across three apertures and mass balance
                % came out at 1e-16. Catch it here rather than letting it
                % print raw, and let the mass balance decide whether the
                % answer is worth having.
                [oldMsg, oldId] = lastwarn('');
                ws = warning('off','MATLAB:nearlySingularMatrix');
                wsb = warning('off','MATLAB:singularMatrix');
                dfn = Solve(dfn, bv, app.FlowKvF.Value);
                warning(ws); warning(wsb);
                [wmsg, ~] = lastwarn;
                illCond = contains(wmsg,'singular') || contains(wmsg,'scaled');
                lastwarn(oldMsg, oldId);
                dt  = toc(t0);

                % Flux crossing a boundary is carried by the edges that JOIN
                % a boundary node to an inner one. An edge whose own Type is 1
                % or 2 runs between two nodes of that same type, both pinned to
                % the same imposed head, so its dP - and its flow - is exactly
                % zero by construction. Summing those gives 0, not the inflow.
                E  = dfn.grh.Edge;
                NT = double([dfn.grh.Node.Type]);
                Qin = 0; Qout = 0;
                for ei = 1:numel(E)
                    nd = E(ei).Nodes;
                    ts = sort([NT(nd(1)), NT(nd(2))]);
                    if ts(1) ~= 0, continue, end        % not a boundary crossing
                    if ts(2) == 1, Qin  = Qin  + abs(E(ei).Flow); end
                    if ts(2) == 2, Qout = Qout + abs(E(ei).Flow); end
                end
                dH   = abs(bv(1) - bv(2));
                K    = NaN;
                if dH > 0 && area > 0, K = Qout * span / (area * dH); end
                bal  = NaN;
                if Qin > 0, bal = abs(Qin - Qout) / Qin; end
                if illCond
                    % conductance spans many orders of magnitude, which is
                    % normal; mass balance is the test that actually matters
                    if isfinite(bal) && bal < 1e-9
                        app.log(sprintf(['Flow: the linear system is badly ' ...
                            'scaled (pipe conductances span a wide range). ' ...
                            'Mass balance came out at %.1e, so the solution ' ...
                            'is sound - the warning is about scaling, not ' ...
                            'rank.'], bal), 'info');
                    else
                        app.log(sprintf(['Flow: the linear system is badly ' ...
                            'scaled AND mass balance is only %.1e. Treat this ' ...
                            'K as unreliable - try a smaller domain, fewer ' ...
                            'fractures, or a network with fewer near-zero ' ...
                            'length pipes.'], bal), 'error');
                    end
                    condNote = 'badly scaled - see the log';
                else
                    condNote = 'fine';
                end

                R = app.Model.results;
                R.flow        = dfn;
                R.flowQin     = Qin;
                R.flowQout    = Qout;
                R.flowK       = K;
                R.flowBalance = bal;
                app.Model.results = R;

                app.FlowInfo.Value = { ...
                    sprintf('percolating  : yes  (%s, %s sides)', upper(dirc), ...
                            app.FlowBCDD.Value)
                    sprintf('pipes        : %d', size(dfn.pip.Pipe,1))
                    sprintf('backbone     : %d segments', size(dfn.bbn.Backbone,1))
                    sprintf('graph        : %d nodes, %d edges', dfn.grh.Size(1), ...
                            dfn.grh.Size(2))
                    sprintf('inflow  Qin  : %.6g', Qin)
                    sprintf('outflow Qout : %.6g', Qout)
                    sprintf('balance      : %.3g  (|Qin-Qout|/Qin, want ~0)', bal)
                    sprintf('conditioning : %s', condNote)
                    sprintf('K effective  : %.6g   = Qout*L/(A*dH)', K)
                    sprintf('  L = %.4g   A = %.4g   dH = %.4g', span, area, dH)
                    sprintf('aperture     : %.4g m', ap)
                    sprintf('solve time   : %.3f s', dt)};
                app.refreshResultsTable(); app.refreshPlotTypes();
                app.log(sprintf(['Flow solved: %d edges, Qout = %.4g, ' ...
                    'K = %.4g (%.2f s).'], dfn.grh.Size(2), Qout, K, dt),'ok');
                app.PlotDD.Value = 'Flow | solution';
                app.renderPlot();
            catch ME
                app.log(['Flow failed: ' ME.message],'error');
                uialert(app.Fig, ME.message, 'Flow failed');
            end
        end

        function [be, span, area] = boundaryElements(~, rgn, is3, dirc, linear)
            %BOUNDARYELEMENTS  Inlet/outlet (and optional side) elements for the
            %   real domain. ADFNE's built-in Line.* / Poly.* constants are unit
            %   box only, so a domain of any other size needs these built here.
            %   Order matters: Pipe prepends them to the network and tests
            %   percolation between element 1 and element 2, so inlet must come
            %   first and outlet second.
            x1 = rgn(1); x2 = rgn(2); y1 = rgn(3); y2 = rgn(4);
            z1 = rgn(5); z2 = rgn(6);
            if is3
                face = @(c) c;                                  % readability
                Xlo = [x1 y1 z1; x1 y1 z2; x1 y2 z2; x1 y2 z1];
                Xhi = [x2 y1 z1; x2 y1 z2; x2 y2 z2; x2 y2 z1];
                Ylo = [x1 y1 z1; x2 y1 z1; x2 y1 z2; x1 y1 z2];
                Yhi = [x1 y2 z1; x2 y2 z1; x2 y2 z2; x1 y2 z2];
                Zlo = [x1 y1 z1; x2 y1 z1; x2 y2 z1; x1 y2 z1];
                Zhi = [x1 y1 z2; x2 y1 z2; x2 y2 z2; x1 y2 z2];
                switch dirc
                    case 'x'
                        be = {face(Xlo); face(Xhi)};
                        span = x2-x1;  area = (y2-y1)*(z2-z1);
                        sides = {Ylo; Yhi; Zlo; Zhi};
                    case 'y'
                        be = {face(Ylo); face(Yhi)};
                        span = y2-y1;  area = (x2-x1)*(z2-z1);
                        sides = {Xlo; Xhi; Zlo; Zhi};
                    otherwise
                        be = {face(Zlo); face(Zhi)};
                        span = z2-z1;  area = (x2-x1)*(y2-y1);
                        sides = {Xlo; Xhi; Ylo; Yhi};
                end
                if linear, be = [be; sides]; end
            else
                Xlo = [x1 y1 x1 y2];  Xhi = [x2 y1 x2 y2];
                Ylo = [x1 y1 x2 y1];  Yhi = [x1 y2 x2 y2];
                switch dirc
                    case 'x'
                        be = [Xlo; Xhi];  span = x2-x1;  area = y2-y1;
                        sides = [Ylo; Yhi];
                    otherwise
                        be = [Ylo; Yhi];  span = y2-y1;  area = x2-x1;
                        sides = [Xlo; Xhi];
                end
                if linear, be = [be; sides]; end
            end
        end

        % ------------------------------------------------------ Export dialog
        function buildExportDialog(app)
            %BUILDEXPORTDIALOG  Export, in a window you visit and leave.
            %   Export was a tab, which gave a terminal action a permanent
            %   470 px of the modelling column. Nobody dwells in export: you
            %   pick formats once and press the button. It is the one place a
            %   separate window is right, because you are not iterating against
            %   the viewport while you do it.
            %
            %   Built hidden at startup rather than on demand, so the fields
            %   keep their values between exports and so onSaveSession can read
            %   OutDirField for its default folder whether or not this window
            %   has ever been opened.
            app.ExportFig = uifigure('Name','Export', ...
                'Position', app.startupFigurePosition(560, 470), ...
                'Tag', 'ADFNE_GUI_export', ...
                'Color', app.BG, 'Visible','off', ...
                'CloseRequestFcn', @(s,e) set(s,'Visible','off'));
            g = uigridlayout(app.ExportFig,[6 1]);
            g.RowHeight = {32,32,22,'1x',40,40};
            g.RowSpacing = 6; g.Padding = [12 12 12 12];
            g.BackgroundColor = app.BG;

            d = uigridlayout(g,[1 3]); d.Layout.Row = 1;
            d.ColumnWidth = {90,'1x',90}; d.Padding=[0 0 0 0];
            tp = ['Where exported files are written. Created if it does ' ...
                  'not exist. Defaults to the exports folder inside the app.'];
            uilabel(d,'Text','Output folder','FontWeight','bold','Tooltip',tp);
            app.OutDirField = uieditfield(d,'text','Value', ...
                fullfile(fileparts(mfilename('fullpath')),'exports'),'Tooltip',tp);
            uibutton(d,'Text','Browse…','Tooltip','Pick the output folder.', ...
                'ButtonPushedFcn',@(s,e) app.onBrowseOut());

            n = uigridlayout(g,[1 2]); n.Layout.Row = 2;
            n.ColumnWidth = {90,'1x'}; n.Padding=[0 0 0 0];
            tp = ['File name without the extension. Every selected format ' ...
                  'writes <base name>.<ext> into the output folder, so one ' ...
                  'export can produce several files at once. An existing ' ...
                  'file of the same name is overwritten.'];
            uilabel(n,'Text','Base name','FontWeight','bold','Tooltip',tp);
            app.BaseNameField = uieditfield(n,'text','Value','adfne_model','Tooltip',tp);

            tp = strjoin({ ...
                'Ctrl or Shift to select several; they are all written at once.'
                ''
                'PNG, PDF, SVG, FIG   a picture of the viewport as it looks'
                '                     right now, so set up the plot first'
                'VTK                  the 3D polygons, for ParaView'
                'SVG / HTML via ADFNE  the traces on the section plane, drawn'
                '                     by ADFNE itself, whichever view is up'
                'MAT                  the whole model, results and settings,'
                '                     which Load reads back'
                'CSV                  one row per fracture, for a spreadsheet'}, newline);
            uilabel(g,'Text','Formats  (multi-select)','FontWeight','bold','Tooltip',tp);

            app.FmtList = uilistbox(g,'Multiselect','on','Items', ...
                {'PNG  | viewport image (300 dpi)', ...
                 'PDF  | viewport, vector', ...
                 'SVG  | viewport, vector', ...
                 'FIG  | MATLAB figure', ...
                 'VTK  | 3D polygons (ParaView)', ...
                 'SVG  | section traces via ADFNE SaveLinesAsSVG2D', ...
                 'HTML | section traces via ADFNE SaveLinesAsHTML2D', ...
                 'MAT  | full model + results', ...
                 'CSV  | fracture table'}, ...
                'ItemsData',{'png','pdf','svg','fig','vtk','asvg','ahtml','mat','csv'}, ...
                'Value',{'png'},'Tooltip',tp);
            app.FmtList.Layout.Row = 4;

            b = uibutton(g,'Text','EXPORT','FontWeight','bold', ...
                'BackgroundColor',app.ACCENT,'FontColor',[1 1 1],'Tooltip', ...
                ['Write every selected format. The image formats capture the ' ...
                 'viewport as it stands, so choose the plot and view you ' ...
                 'want before pressing this. The log lists what was written.'], ...
                'ButtonPushedFcn',@(s,e) app.onExportAndClose());
            b.Layout.Row = 5;

            uilabel(g,'Text',['VTK writes the 3D polygon set for ParaView.  ' ...
                'The two ADFNE formats write the section traces as <base ' ...
                'name>_traces.svg / .html.'], ...
                'WordWrap','on','FontSize',11,'FontColor',[.4 .4 .4], ...
                'Tooltip',tp);
        end

        function openExportDialog(app)
            if isempty(app.ExportFig) || ~isvalid(app.ExportFig)
                app.buildExportDialog();
            end
            app.ExportFig.Visible = 'on';
            figure(app.ExportFig);
        end

        function onExportAndClose(app)
            % Export is terminal, so the window goes away and the log -- which
            % is where both the file list and any failure land -- is left
            % visible behind it.
            app.onExport();
            if ~isempty(app.ExportFig) && isvalid(app.ExportFig)
                app.ExportFig.Visible = 'off';
            end
        end

        % -------------------------------------------------------- Library tab
        function openConsole(app)
            %OPENCONSOLE  The function console, in its own window.
            %   It used to be a tab, which put a MATLAB prompt in front of every
            %   user whether or not they wanted one. Most of what it offered
            %   duplicated the Analysis tab and the plot controls; what did not -
            %   the geostatistics - moved into Analysis where people look for
            %   it. What is left here is an expert escape hatch: 367 functions,
            %   most of them internal plumbing, reachable when you know what you
            %   are after.
            if ~isempty(app.ConsoleFig) && isvalid(app.ConsoleFig)
                figure(app.ConsoleFig); return
            end
            app.ConsoleFig = uifigure('Name','ADFNE function console', ...
                'Position', app.startupFigurePosition(760, 720), ...
                'Tag', 'ADFNE_GUI_console', 'Color', app.BG);
            g = uigridlayout(app.ConsoleFig,[8 1]);
            g.RowHeight = {28, 224, 104, 46, 62, 60, 16, '1x'};
            g.RowSpacing = 5; g.Padding=[10 10 10 10];

            s = uigridlayout(g,[1 3]); s.Layout.Row = 1;
            s.ColumnWidth = {58,'1x',124}; s.Padding=[0 0 0 0];
            uilabel(s,'Text','Search','FontWeight','bold');
            app.SearchField = uieditfield(s,'text','ValueChangedFcn',@(s2,e) app.onSearch(), ...
                'Placeholder','filter the function list…','Enable','off');
            app.AllFcnCB = uicheckbox(s,'Text','All 367 functions','Value',false, ...
                'ValueChangedFcn',@(s2,e) app.onToolboxToggle());

            % The toolbox tree and the raw alphabetical list share one cell;
            % the checkbox above swaps them. The tree is what a newcomer sees:
            % grouped by the question being asked, not by the author's function
            % names, half of which carry no description in the source at all.
            lg = uigridlayout(g,[1 1]); lg.Layout.Row = 2; lg.Padding=[0 0 0 0];
            app.ToolTree = uitree(lg,'SelectionChangedFcn',@(s2,e) app.onToolSelected());
            app.ToolTree.Layout.Row = 1; app.ToolTree.Layout.Column = 1;
            app.FcnList = uilistbox(lg,'Items',{}, ...
                'ValueChangedFcn',@(s2,e) app.onFcnSelected(),'Visible','off');
            app.FcnList.Layout.Row = 1; app.FcnList.Layout.Column = 1;

            app.HelpArea = uitextarea(g,'Editable','off','FontName','Consolas','FontSize',11);
            app.HelpArea.Layout.Row = 3;

            app.ConsoleArea = uitextarea(g,'FontName','Consolas','FontSize',12, ...
                'Value',{'% select a function above, then Insert template'});
            app.ConsoleArea.Layout.Row = 4;

            % Two rows on purpose. The panel is 470 px wide, so a single row
            % of four fixed-width buttons overflowed it: the flexible column
            % collapsed to nothing and EVALUATE - the one button that matters -
            % disappeared entirely. All columns are proportional now, so
            % nothing can be squeezed out however the panel is resized.
            b = uigridlayout(g,[2 3]); b.Layout.Row = 5;
            b.ColumnWidth = {'1x','1x','1x'}; b.RowHeight = {30,26};
            b.Padding=[0 0 0 0]; b.RowSpacing = 4; b.ColumnSpacing = 4;
            ev = uibutton(b,'Text','EVALUATE','FontWeight','bold', ...
                'BackgroundColor',app.ACCENT,'FontColor',[1 1 1], ...
                'ButtonPushedFcn',@(s2,e) app.onEvaluate());
            ev.Layout.Row = 1; ev.Layout.Column = [1 3];
            uibutton(b,'Text','Insert template','ButtonPushedFcn',@(s2,e) app.onInsertTemplate());
            uibutton(b,'Text','Plot variable','ButtonPushedFcn',@(s2,e) app.onPlotVar());
            uibutton(b,'Text','To workspace','ButtonPushedFcn',@(s2,e) app.onToWorkspace());

            app.OutArea = uitextarea(g,'Editable','off','FontName','Consolas','FontSize',11);
            app.OutArea.Layout.Row = 6;

            uilabel(g,'Text','Variables  (available to the console above)','FontWeight','bold');

            app.VarTable = uitable(g,'ColumnName',{'Name','Class','Size'}, ...
                'ColumnWidth',{140,110,'auto'},'Data',cell(0,3));
            try, app.VarTable.SelectionType = 'row'; catch, end
            app.VarTable.Layout.Row = 8;
            app.buildToolTree();
            app.syncVars();
        end

        function onToolboxToggle(app)
            allf = app.AllFcnCB.Value;
            on = @(b) matlab.lang.OnOffSwitchState(b);
            app.ToolTree.Visible  = on(~allf);
            app.FcnList.Visible   = on(allf);
            app.SearchField.Enable = on(allf);
        end

        function buildToolTree(app)
            delete(app.ToolTree.Children);
            C = app.toolCatalogue();
            cats = unique(C(:,1),'stable');
            for i = 1:numel(cats)
                pn = uitreenode(app.ToolTree,'Text',cats{i});
                for j = find(strcmp(C(:,1), cats{i}))'
                    uitreenode(pn,'Text',C{j,2},'NodeData',j);
                end
                expand(pn);
            end
        end

        function onToolSelected(app)
            n = app.ToolTree.SelectedNodes;
            if isempty(n) || isempty(n.NodeData), return, end
            C = app.toolCatalogue(); k = n.NodeData;
            switch C{k,5}
                case '2D', applies = 'the 2D section view';
                case '3D', applies = 'the 3D view';
                otherwise, applies = 'either view';
            end
            app.HelpArea.Value = [ {C{k,2}}; {''}; {C{k,3}}; {''}
                {sprintf('Works in : %s', applies)}
                {sprintf('Calls    : %s', C{k,6})}; {''}
                {'The call below is filled in from your current model.'}
                {'Press EVALUATE to run it, or edit it first.'} ];
            app.ConsoleArea.Value = {C{k,4}};
        end

        function C = toolCatalogue(~)
            %TOOLCATALOGUE  What you might want to ask, in plain language.
            %   {category, title, question, call, view, functions used}
            %   The library has 367 functions and 175 of them carry no
            %   description in the source, so this list is curated rather than
            %   generated: these are the ones worth reaching for, worded as
            %   questions and pre-filled with the current model's variables.
            C = {
            'Orientation', 'Stereonet of fracture poles', ...
              'Where do the joint sets plot on an equal-area net?', ...
              'o = Orientation(fnm); Stereonet([o.Dip],[o.Dir],''density'',true,''ndip'',8)', ...
              '3D', 'Orientation, Stereonet'
            'Orientation', 'Dip and dip direction of every fracture', ...
              'Tabulate the orientation of each fracture.', ...
              'o = Orientation(fnm); orientations = [[o.Dip]'' [o.Dir]'']', ...
              '3D', 'Orientation'
            'Orientation', 'Trace directions on the face', ...
              'Which way do the mapped traces run on the section?', ...
              'ang = mod(atan2d(traces(:,4)-traces(:,2), traces(:,3)-traces(:,1)), 180); histogram(ang, 18)', ...
              '2D', 'plain MATLAB, on traces'
            'Size and intensity', 'Fracture size statistics', ...
              'How big are the fractures - smallest, mean, largest, spread?', ...
              'sizes = Length(fnm); Stats_R1(sizes)', ...
              'any', 'Length, Stats_R1'
            'Size and intensity', 'Size distribution', ...
              'Plot the histogram of fracture sizes.', ...
              'histogram(Length(fnm), 24)', ...
              'any', 'Length'
            'Size and intensity', 'Trace length on the face', ...
              'How long are the traces on the section - the quantity you measure when mapping?', ...
              'tl = sqrt(sum((traces(:,3:4)-traces(:,1:2)).^2,2)); Stats_R1(tl)', ...
              '2D', 'Stats_R1'
            'Size and intensity', 'Area of every fracture', ...
              'The area of each fracture, and the total fracture area.', ...
              'areas = cellfun(@(q) abs(polygonArea3d(q)), fnm); totalArea = sum(areas)', ...
              '3D', 'polygonArea3d'
            'Size and intensity', 'P32 - fracture area per unit volume', ...
              'The intensity measure used to calibrate a DFN against field mapping.', ...
              'a = cellfun(@(q) abs(polygonArea3d(q)), fnm); P32 = sum(a)/prod(rgn([2 4 6])-rgn([1 3 5]))', ...
              '3D', 'polygonArea3d'
            'Connectivity', 'Connected clusters', ...
              'How many separate connected groups of fractures are there?', ...
              '[~,~,La] = Intersect(fnm); Ra = Relabel(La); nClusters = max(Ra)', ...
              'any', 'Intersect, Relabel'
            'Connectivity', 'Intersections between fractures', ...
              'Where do fractures meet, and how many intersections are there?', ...
              '[xts, ids] = Intersect(fnm); nIntersections = size(ids,1)', ...
              'any', 'Intersect'
            'Connectivity', 'Isolated traces', ...
              'Which traces on the section touch nothing else?', ...
              'isolated = Isolated(traces); nIsolated = sum(isolated)', ...
              '2D', 'Isolated'
            'Geostatistics', 'Variogram of a measured property', ...
              'How does a measured value correlate with distance? Swap in your own data for pts and vals.', ...
              'pts = Center(fnm); vals = Length(fnm); [d,g,v] = Variocloud(pts(:,1:2), vals, [], true)', ...
              '3D', 'Center, Length, Variocloud'
            'Geostatistics', 'Fit a variogram model', ...
              'Fit a spherical model and plot it.', ...
              'Variomodel({''name'',''sph'',''nugget'',0,''sill'',1,''range'',0.3}, 0:0.01:1, true)', ...
              'any', 'Variomodel'
            'Geostatistics', 'Upscale a property grid', ...
              'Coarsen a grid by harmonic, geometric or arithmetic averaging.', ...
              'coarse = Upscaling(abs(peaks(32)), ''geometric'', 2)', ...
              'any', 'Upscaling'
            'Geometry', 'Fracture centres', ...
              'The centroid of every fracture.', ...
              'centres = Center(fnm)', ...
              'any', 'Center'
            'Geometry', 'Bounding box of the network', ...
              'The smallest box containing every fracture.', ...
              'box = Bbox(fnm,''pp'')', ...
              'any', 'Bbox'
            'Export and viewing', 'Export for ParaView', ...
              'Write the 3D fractures as a VTK file.', ...
              'Export(fnm, fullfile(''exports'',''model.vtk''))', ...
              '3D', 'Export'
            'Export and viewing', 'Export the section traces as a web page', ...
              'An HTML view of the trace map you can open in a browser.', ...
              'SaveLinesAsHTML2D(fullfile(''exports'',''traces.html''), traces, 800, 800, ''black'', 1)', ...
              '2D', 'SaveLinesAsHTML2D (ADFNE 1.0 - the 1.5 HTML export is broken)'
            'Export and viewing', 'Draw in a custom colour', ...
              'Redraw the network with your own colour and transparency.', ...
              'Draw(''ply'', fnm, ''fc'', [0.85 0.33 0.10], ''fa'', 0.45)', ...
              '3D', 'Draw'
            };
        end
    end

    %% ----------------------------------------------------------- root / paths
    methods (Access = public, Hidden = true)

        function attachRoot(app, root)
            kind = ADFNE_GUI.rootKind(root);
            if kind == 0
                app.PathLbl.Text = 'ADFNE folder not found | use "ADFNE folder…"';
                app.log('ADFNE root not found. Pick the folder containing GenFNM2D.m.','error');
                return
            end
            app.AdfneRoot = root;
            app.HasR15    = (kind == 2);
            addpath(root);          % not genpath: R2015a is added by
            addpath(app.DepsRoot);  % armGlobals, and only when needed
            app.PathLbl.Text = root;
            if app.HasR15
                app.initR15Globals();
                app.log('Library: merged ADFNE 1.5 + 1.0. Generator = DFN (R1.5).','ok');
            else
                app.log(['Library: ADFNE 1.0 only. The R1.5 generator, shapes and ' ...
                         'flow solver are unavailable - lib\adfne is incomplete.'],'warn');
            end
            app.refreshEngineUI();
            app.buildFunctionIndex();
            app.log(sprintf('ADFNE root: %s  (%d functions indexed)', root, numel(app.FcnNames)),'ok');
        end

        function initR15Globals(app)
            %INITR15GLOBALS  Arm ADFNE 1.5's globals without running Globals.m.
            %   Globals.m is a script that does "clear all", "clc", "clf" and
            %   "warning off". Inside an app that would wipe this figure and the
            %   caller's workspace, so the same variables are set directly. 1.5
            %   is put in Silent mode: its progress text would go to the command
            %   window, and the GUI has its own log.
            ADFNE_GUI.armGlobals(app.AdfneRoot);
        end

        function buildFunctionIndex(app)
            d = dir(fullfile(app.AdfneRoot,'*.m'));
            if exist(app.DepsRoot,'dir')
                d = [d; dir(fullfile(app.DepsRoot,'*.m'))];
            end
            [~, ia] = unique({d.name}, 'stable'); d = d(ia);
            names = cell(numel(d),1); files = cell(numel(d),1);
            for i = 1:numel(d)
                [~, nm] = fileparts(d(i).name);
                names{i} = nm; files{i} = fullfile(d(i).folder, d(i).name);
            end
            [names, ix] = sort(names);
            app.FcnNames = names; app.FcnFiles = files(ix);
            app.FcnList.Items = app.FcnNames;
            if ~isempty(app.FcnNames)
                app.FcnList.Value = app.FcnNames{1};
                app.onFcnSelected();
            end
        end

        function onPickRoot(app)
            p = uigetdir(pwd, 'Select the ADFNE folder (the one containing GenFNM2D.m)');
            figure(app.Fig);
            if isequal(p,0), return; end
            app.attachRoot(p);
        end

        function onSelfTest(app)
            dlg = uiprogressdlg(app.Fig,'Title','Self-test','Message','Running dependency checks…', ...
                'Indeterminate','on');
            c = onCleanup(@() close(dlg));
            out = evalc('ADFNE_GUI.smoketest(app.AdfneRoot)'); %#ok<EVLCS>
            app.log('--- self-test ---');
            for L = string(splitlines(strtrim(out)))'
                if strlength(L)==0, continue; end
                if contains(L,'FAIL'), app.log(char(L),'error'); else, app.log(char(L),'ok'); end
            end
        end
    end

    %% -------------------------------------------------------------- Model tab
    methods (Access = public, Hidden = true)

        function resetModel(app)
            % setid is declared here even though only GENERATE fills it: every
            % plot that colours by joint set reads it, and a struct that omits
            % a field its readers expect fails at the first draw before there
            % is a model -- which is exactly when the section and trace-map
            % previews are meant to work.
            app.Model = struct('mode','2D','fnm',[],'La',[],'rgn',[0 1 0 1 0 1], ...
                'info',struct(),'results',struct(),'sets',[],'setid',[]);
            % A fresh app starts with one typical set so a first GENERATE
            % works; the table may be emptied afterwards. Push it into the
            % table here - applyModeToTable no longer refills an empty one.
            if isempty(app.Sets)
                app.Sets = app.defaultSet();
                if ~isempty(app.SetTable) && isvalid(app.SetTable), app.applyModeToTable(); end
            end
            if ~isempty(app.FlowInfo)
                app.FlowInfo.Value = {'No flow solution yet.'};
            end
            app.refreshPlotTypes();
            app.refreshAnalyses();
            app.refreshStateBar();
        end

        function onTabChanged(app)
            % Most generative controls deliberately have no edit callback.
            % Compare their complete state at a natural interaction boundary
            % instead, so adding a control cannot leave stale-state wiring
            % behind. Viewing controls are absent from this signature.
            app.refreshStateBar();
        end

        function onModeChanged(app, ~)
            % Switching view does not touch the model: same fractures, same
            % seed, same everything. Only the way you look at them changes.
            %
            % It does dismiss the trace map. Picking a View means "show me the
            % model like this", and the trace map is a preview of an INPUT --
            % leaving it up made "2D | section face" show an imported map where
            % the generated section belonged.
            if any(strcmp(app.PlotDD.Value,{'Trace map','Mapped planes'})), app.PrevPlotTM = ''; end
            app.harvestSets();
            app.applyModeToTable();
            if app.is2DView() && ~isempty(app.Model.fnm) && ...
                    (~isfield(app.Model,'sec') || isempty(app.Model.sec))
                app.computeSection();
            end
            app.refreshAnalyses();
            app.refreshEngineUI();
            app.refreshPlotTypes();
            if ~isempty(app.Model.fnm), app.renderPlot(); end
        end

        function refreshEngineUI(app)
            %REFRESHENGINEUI  Enable only what the current mode and library allow.
            if isempty(app.ModeDD), return, end
            is2 = app.is2DView();
            on  = @(b) matlab.lang.OnOffSwitchState(b);
            % Generation is always 3D, so the shape, facet and domain controls
            % stay live in both views; only the section fields depend on it.
            app.ShapeDD.Enable   = on(true);
            app.FacetSpin.Enable = on(any(strcmp(app.ShapeDD.Value,{'c','e'})));
            el = strcmp(app.ShapeDD.Value,'e');
            for h = [app.AspectField, app.AspectSdField, app.AxisDD, app.AspectLawDD]
                if ~isempty(h) && isvalid(h), h.Enable = on(el); end
            end
            if ~isempty(app.ClusterField) && isvalid(app.ClusterField)
                app.ClusterField.Enable = on(~strcmp(app.centresModel(),'poisson'));
            end
            app.ASepField.Enable = on(true);
            app.DSepField.Enable = on(true);
            for i = 1:6, app.RgnFields(i).Enable = on(true); end
            % the section plane is also the 3D band's plane, so it stays
            % live in the 3D view whenever a 3D source is selected
            for f = [app.SecDipF, app.SecDirF, app.SecOffF]
                if ~isempty(f), f.Enable = on(is2 || app.is3DSource()); end
            end
            % the intersect view is a picture of the 2D section, so it belongs
            % to that view only - greyed out rather than silently switching
            if ~isempty(app.SecShowCB), app.SecShowCB.Enable = on(is2); end
            app.syncClipEnable();
            app.GenBtn.Enable = on(app.HasR15);
            if ~isempty(app.FlowRunBtn)
                app.FlowRunBtn.Enable = on(app.HasR15);
                app.FlowMtdDD.Enable = on(~is2);
            end
            % Generation has one persistent home. Its label is an action, not
            % a second state display; current/stale and conditioning details
            % belong to the state bar beside it.
            app.GenBtn.Text = 'GENERATE';
            app.refreshStateBar();
        end

        function [cn, hint, oricol] = setColumns(~)
            %SETCOLUMNS  Joint sets are 3D properties of the rock mass, so there
            %   is one set of columns whatever the view. What appears on a
            %   section - trace orientation, trace length - is a consequence of
            %   these and of the section plane, never an input.
            % Short headers on purpose: eight columns have to fit a 470 px
            % panel, and 'DipDir (deg)' alone pushed L min/mean/max off the
            % edge behind a horizontal scrollbar. Units are in the hint below.
            cn = {'N','Dip','dDip','DipDir','dDDir','Lmin','Lmean','Lmax','Lp'};
            oricol = 4;                                     % DipDir
            % The conventions are reference material - read once, then in the
            % way. They live on the table's tooltip now; the visible label is
            % one line, which keeps GENERATE above the fold.
            hint = 'Joint sets  (hover for help)';
        end

        function [nm, P] = presetNames(~)
            %PRESETNAMES  Typical rock masses, so a first model does not start
            %   from a blank table. Each row of P is a joint set:
            %     N  Dip  dDip  DipDir  dDipDir  Lmin  Lmean  Lmax
            %   dDip/dDipDir are negative, i.e. Fisher concentrations: about 30
            %   for a well-defined set, 12-15 for a scattered one.
            %   Sizes are fractions of a unit domain - rescale with the domain.
            P = { ...
              'Choose a preset…',          [] ; ...
              'Jointed granite (3 sets)',  [150 85 -30 000 -30 0.05 0.15 0.50
                                            150 85 -30 090 -30 0.05 0.15 0.50
                                            100 10 -20 000 -12 0.08 0.22 0.60] ; ...
              'Bedded sedimentary',        [200 05 -45 000 -10 0.10 0.30 0.80
                                            120 80 -30 090 -25 0.04 0.12 0.35
                                            100 80 -30 180 -25 0.04 0.12 0.35] ; ...
              'Massive rock (sparse)',     [ 40 70 -25 120 -25 0.15 0.35 0.90] ; ...
              'Heavily fractured',         [400 75 -15 030 -15 0.04 0.12 0.35
                                            400 70 -15 120 -15 0.04 0.12 0.35
                                            300 20 -12 000 -10 0.04 0.14 0.40
                                            250 60 -12 250 -12 0.04 0.12 0.35] ; ...
              'Tunnel face (2 joints + bedding)', ...
                                           [180 78 -30 145 -30 0.06 0.18 0.55
                                            140 65 -22 250 -22 0.05 0.14 0.45
                                            110 15 -25 000 -15 0.08 0.25 0.70] };
            nm = P(:,1)';
        end

        function onPreset(app)
            [nm, P] = app.presetNames();
            k = find(strcmp(nm, app.PresetDD.Value), 1);
            if isempty(k) || isempty(P{k,2}), return, end
            D = P{k,2};
            % sizes in the presets are fractions of a unit box; scale to this
            % domain so a preset means the same thing at any scale
            rgn = [app.RgnFields.Value];
            sc = mean([rgn(2)-rgn(1), rgn(4)-rgn(3), rgn(6)-rgn(5)]);
            if isfinite(sc) && sc > 0, D(:,6:8) = D(:,6:8) * sc; end
            D = app.padSets(D);
            % a preset gives the exponential's numbers; carry a sensible Lp
            % for the other laws so switching does not land on zero
            D(:,9) = app.defaultLp(D);
            app.Sets = D;
            app.applyModeToTable();
            app.refreshCondUI();
            app.log(sprintf(['Preset "%s": %d joint sets, sizes scaled to a ' ...
                'domain of about %.4g. Edit any cell to suit your mapping.'], ...
                app.PresetDD.Value, size(D,1), sc), 'ok');
        end

        function lp = defaultLp(app, D)
            %DEFAULTLP  A reasonable Lp for the current law, per row.
            switch app.sizeLaw()
                case {'logn','norm'}, lp = D(:,7) * 0.5;       % sd half the mean
                case 'pow',  lp = 2.5 * ones(size(D,1),1);      % Bonnet et al. range
                case {'weib','gam'}, lp = 2 * ones(size(D,1),1); % shape 2: peaked
                otherwise,   lp = zeros(size(D,1),1);
            end
        end

        function h = lpHeader(app)
            %LPHEADER  What the ninth column holds under the current law.
            switch app.sizeLaw()
                case {'logn','norm'}, h = 'L sd';
                case 'pow',           h = 'L exp';
                case {'weib','gam'},  h = 'L shape';
                otherwise,            h = 'Lp -';
            end
        end

        function row = defaultSet(~)
            %DEFAULTSET  One typical joint set.
            %       N  Dip  dDip  DDir  dDDir  Lmin  Lmean  Lmax  Lp
            %   Lp is the size law's extra parameter: unused for the
            %   exponential, the standard deviation for the log-normal, the
            %   exponent for the power law. Zero means "not set".
            row = [150   45   -20   180    -20  0.05   0.15  0.50  0];
        end

        function harvestSets(app, ~)
            %HARVESTSETS  Fold the visible table back into the store.
            %   An empty table is a legitimate state now - "no joint sets
            %   yet" - and must come back as zeros(0,9), not as whatever the
            %   store held before.
            d = app.SetTable.Data;
            if isempty(d), app.Sets = zeros(0,9); return, end
            d9 = app.padSets(d);
            if size(d9,2) ~= 9, return, end
            % a script may write an eight-column matrix straight into the
            % table; keep the table and the store the same shape
            if size(d,2) ~= 9, app.SetTable.Data = d9; end
            app.Sets = d9;
        end

        function D = padSets(~, D)
            %PADSETS  Eight-column tables (before the size law existed) get
            %   an Lp of 0, which every law reads as "not set".
            if ~isempty(D) && size(D,2) == 8, D(:,9) = 0; end
        end

        function D = padTraceSets(~, D)
            %PADTRACESETS  Six-column trace tables (before the size law reached
            %   the synthetic traces) get an Lp of 0, "not set".
            if ~isempty(D) && size(D,2) == 6, D(:,7) = 0; end
        end

        function S = traceRowsAsSets(~, D)
            %TRACEROWSASSETS  Trace-table rows [N Dir Kappa Lmin Lmean Lmax Lp]
            %   in the joint-set layout drawSizes and defaultLp read: the size
            %   columns 6..9, the orientation columns unused.
            if isempty(D), S = zeros(0,9); return, end
            if size(D,2) == 6, D(:,7) = 0; end
            S = [D(:,1:3), zeros(size(D,1),2), D(:,4:7)];
        end

        function applyModeToTable(app)
            % A malformed store gets the default row; an EMPTY one stays
            % empty. The table used to refill itself with a placeholder row
            % that could not be removed, and the placeholder looked like
            % data - someone starting from a real mapped face had to edit
            % it rather than start clean, and nothing said it was a
            % placeholder. Now the guards sit where they belong: GENERATE
            % and FIT refuse an empty table and say what to do.
            app.Sets = app.padSets(app.Sets);
            if ~isempty(app.Sets) && size(app.Sets,2) ~= 9
                app.Sets = app.defaultSet();
            end
            if isempty(app.Sets), app.Sets = zeros(0,9); end
            [cn, hint] = app.setColumns();
            if ~strcmp(app.intensityMode(), 'N'), cn{1} = app.intensityMode(); end
            switch app.orientModel()
                case 'fisher', cn{3} = 'kappa';  cn{5} = '-';
                case 'bvn',    cn{3} = 'sd dip'; cn{5} = 'sd dir';
                case 'kent',   cn{3} = 'kappa';  cn{5} = 'beta';
                case 'bingham',cn{3} = 'k strk'; cn{5} = 'k dip';
                case 'boot',   cn{3} = 'jitter'; cn{5} = '-';
            end
            cn{9} = app.lpHeader();
            if isempty(app.Sets)
                hint = 'No joint sets: Add set, or a preset';
            end
            app.SetTable.ColumnName = cn;
            app.SetTable.Data = app.Sets;
            app.SetTable.ColumnEditable = true(1, numel(cn));
            app.SetTable.ColumnFormat = repmat({'bank'}, 1, numel(cn));
            % The set number adds no information here and consumes the width
            % needed to display the numeric values without truncation.
            app.SetTable.RowName = {};
            app.SetTable.ColumnWidth = {48, 48, 50, 54, 54, 44, 56, 48, 44};
            % strjoin with newline, not sprintf with escapes: the tooltip
            % is plain text and this keeps it readable in the source
            app.SetTable.Tooltip = strjoin({ ...
                'One row per joint set. Angles in degrees.'
                ''
                'N        fractures in this set - or, with "P32 per set"'
                '         chosen above the table, the set''s fracture area'
                '         per unit domain volume, turned into a count on'
                '         GENERATE'
                'Dip      0 = horizontal, 90 = vertical'
                'DipDir   direction the steepest line points down toward,'
                '         measured in the XY plane ANTICLOCKWISE from +X:'
                '         0 = +X, 90 = +Y. This is the mathematical'
                '         convention, not a compass bearing - for compass'
                '         data, set +X to north and enter 360 - bearing.'
                ''
                'With the Fisher model chosen above the table, the third'
                'column is one kappa for the pole and the fifth is unused.'
                ''
                'dDip and dDDir are the scatter about those means:'
                '     0   every fracture on the mean'
                '   > 0   uniform, plus or minus that many degrees'
                '   < 0   von Mises, with kappa = the absolute value'
                ''
                'The same kappa is NOT the same spread for the two: ADFNE'
                'draws the dip scatter compressed by a quarter, so'
                '   dDDir -30  is about +/-10 deg,  -12 about +/-16 deg'
                '   dDip  -30  is about +/-2.6 deg, -2  about +/-10 deg'
                'FIT writes dDip in this convention from the measured spread.'
                ''
                'Lmin, Lmean, Lmax, Lp  fracture size (a diameter), in'
                'domain units, drawn from the size law chosen under Options'
                'and truncated to [Lmin, Lmax]:'
                '  exponential   mean Lmean;  Lp unused'
                '  log-normal    mean Lmean, standard deviation Lp'
                '  power law     density ~ L^-Lp on [Lmin, Lmax];  Lmean unused'
                ''
                'Lmean is the law''s own mean, before truncation. Cutting'
                'off the small sizes lifts the mean of what you actually'
                'get, so exponential 0.3 / 1.0 / 4.0 realises 1.21, not'
                '1.00. Check the number the info box reports.'}, newline);
            % the label says "hover the table"; make hovering the label work
            % too, since that is where the eye goes first. inRegister writes
            % the text, the register tag and the tint together, so this label
            % and the trace-statistics label below it can never drift into
            % looking like each other again.
            app.SetHintLbl.Tooltip = app.SetTable.Tooltip;
            app.inRegister(app.SetHintLbl,'gen',hint);
        end

        function onAddSet(app)
            % A new row gets typical values, not blanks and not a copy of the
            % row above - two identical sets are the same as one set with twice
            % the count - so both orientation fields step 90 degrees on.
            app.harvestSets();
            row = app.defaultSet();
            if ~isempty(app.Sets) && isfinite(app.Sets(end,4))
                row(4) = mod(app.Sets(end,4) + 90, 360);     % DipDir
            end
            app.Sets = [app.Sets; row];
            app.applyModeToTable();
            app.refreshCondUI();
            [~, ~, oricol] = app.setColumns();
            app.log(sprintf(['Added set %d with default values (%s = %g). ' ...
                'Edit the row to match your mapped set.'], size(app.Sets,1), ...
                app.SetTable.ColumnName{oricol}, app.SetTable.Data(end,oricol)));
        end

        function onRemoveSet(app)
            %ONREMOVESET  Drop the selected row, or the last one. Down to
            %   none: the table may be empty, and says so when it is.
            app.harvestSets();
            if isempty(app.Sets), return, end
            r = size(app.Sets,1);
            try
                sel = app.SetTable.Selection;
                if ~isempty(sel), r = sel(1); end
            catch, end %#ok<CTCH>
            r = min(max(r, 1), size(app.Sets,1));
            app.Sets(r,:) = [];
            app.applyModeToTable();
            app.refreshCondUI();
            app.refreshStateBar();
            if isempty(app.Sets)
                app.log(['No joint sets left. Add one with Add set, pick a preset, ' ...
                    'or import mapped planes on the Conditioning tab and FIT ' ...
                    'them - FIT still needs one row per set to fill in.']);
            end
        end

        function onGenerate(app)
            if isempty(app.AdfneRoot)
                uialert(app.Fig,'Set the ADFNE folder first.','No ADFNE root'); return
            end
            app.harvestSets();
            if isempty(app.Sets)
                app.guideNoSets('Nothing to generate yet.');
                return
            end
            sh0 = app.shapeSpec();
            if (strcmp(app.sizeLaw(),'boot') || strcmp(app.orientModel(),'boot') || ...
                    (strcmp(sh0.kind,'e') && strcmp(sh0.aspectLaw,'boot'))) && isempty(app.PlanesLocal)
                app.guideNoPlanesForBootstrap(); return
            end
            if strcmp(app.sizeLaw(),'boot') && app.bandClips()
                app.guideClippedBootstrap(); return
            end
            % conditioning on a synthetic table with no rows: the same
            % guidance, before anything is built
            if ~isempty(app.CondCB) && app.CondCB.Value && ~isempty(app.CondSrcDD)
                app.harvestCondTable();
                if strcmp(app.CondSrcDD.Value,'syn') && isempty(app.TraceSets)
                    app.guideNoSynthetic('trace statistics'); return
                elseif strcmp(app.CondSrcDD.Value,'syn3') && isempty(app.PlaneSets)
                    app.guideNoSynthetic('plane statistics'); return
                end
            end
            cl = app.busy('Building the fracture network…', true, 'generate'); %#ok<NASGU>
            try
                if app.RandSeedCB.Value
                    sd = randi(1e6); app.SeedSpin.Value = sd;
                else
                    sd = app.SeedSpin.Value;
                end
                rng(sd);
                app.Model.La = [];              % drop labels from any previous model
                app.Model.results = struct();
                rv  = [app.RgnFields.Value];
                app.checkDomain(rv);
                rgn = rv;
                app.harvestSets();
                D   = app.SetTable.Data;
                bad = find(any(~isfinite(D), 2));
                % column 1 may be a P32: turn it into the count DFN takes,
                % and keep the table as the user wrote it
                Dcounts = app.countsFor(D, rv);
                if ~isempty(bad)
                    error('ADFNE:IncompleteSet', ...
                        ['Fracture set row(s) ' num2str(bad(:)') ' have empty or invalid cells.' newline ...
                         'Fill in every column, or use Remove Set to drop the row.']);
                end
                mode = app.ModeDD.Value;
                t0 = tic;

                if ~app.HasR15
                    error('ADFNE:NoR15', ...
                        ['This Model tab drives ADFNE 1.5''s DFN generator, which is ' ...
                         'not on the current path.' newline 'The app expects the merged ' ...
                         'library in lib\adfne (it should contain DFN.m).']);
                end
                % The model is always 3D. The 2D view is a section through it,
                % computed after generation, so switching view never regenerates
                % and the 2D traces always belong to this exact rock mass.
                rgn3 = rgn;
                bbx  = app.bbx15(rgn, 3);
                shp  = app.ShapeDD.Value;
                if strcmp(shp,'l'), shp = 'legacy'; end         % not c|e|s
                fnm = {}; sid = [];
                for i = 1:size(D,1)
                    out = DFN('dim',3,'n',round(Dcounts(i,1)), ...
                              'dip',D(i,2),'ddip',D(i,3), ...
                              'dir',D(i,4),'ddir',D(i,5), ...
                              'minl',D(i,6),'mu',D(i,7),'maxl',D(i,8), ...
                              'shape',shp,'q',app.FacetSpin.Value, ...
                              'bbx',[0,0,0,1,1,1]);
                    P = app.applySizeLaw(out.Orig, D(i,:));     % the chosen size law
                    P = app.applyOrientation(P, D(i,:));        % Fisher poles, if chosen
                    P = app.applyShape(P);                      % and shape
                    if strcmp(app.centresModel(), 'poisson')
                        P = app.spreadPolys3D(P, rgn3);         % unit cube -> domain
                    else                                        % clustered centres
                        dg = norm(rgn3([2 4 6]) - rgn3([1 3 5]));
                        P = app.placePolys(P, app.drawCentres(numel(P), app.boxSampler(rgn3), dg));
                    end
                    P = Clip(P, bbx);
                    P = app.cleanPolys(P);
                    fnm = [fnm; P]; %#ok<AGROW>
                    sid = [sid; i*ones(numel(P),1)]; %#ok<AGROW>
                end
                % --- Enhanced Baecher: terminate against older fractures --
                [fnm, cutN] = app.applyTermination(fnm);
                if any(cutN)
                    app.log(sprintf(['Terminated %d of %d fractures at an older ' ...
                        'fracture''s plane (%g%% of those intersecting one).'], ...
                        nnz(cutN), numel(fnm), app.TermField.Value));
                end
                % --- conditioning on mapped joint planes in a band --------
                condN = 0;
                app.Model.band = [];
                if ~isempty(app.CondCB) && app.CondCB.Value && app.is3DSource()
                    band = app.bandGeometry(rgn);
                    app.harvestCondTable();
                    [CP, csid] = app.planesFor(band);
                    app.Model.band = band;
                    if isempty(CP)
                        app.log('Conditioning is on but there are no joint planes.','warn');
                    else
                        % the mapped band is exhaustive, so a stochastic
                        % fracture may not reach into it; drop those first
                        if app.CondExclCB.Value
                            bad = app.hitsBand(fnm, band);
                            fnm = fnm(~bad); sid = sid(~bad);
                            app.log(sprintf(['Mapped band is complete: dropped %d ' ...
                                'stochastic fractures that reached into it.'], sum(bad)));
                        end
                        csid = app.setsForPlanes(CP, csid, D);
                        keep = true(numel(CP),1);
                        for ci = 1:numel(CP)
                            Q = app.cleanPolys(Clip(CP(ci), bbx));
                            if isempty(Q), keep(ci) = false; else, CP{ci} = Q{1}; end
                        end
                        nAll = numel(CP);
                        CP = CP(keep); csid = csid(keep);
                        fnm = [CP; fnm]; sid = [csid; sid];
                        condN = numel(CP);
                        app.log(sprintf(['Conditioned on %d mapped joint planes in a ' ...
                            'band %.3g thick -> %d placed exactly%s.'], nAll, band.thk, ...
                            condN, app.iff(condN < nAll, sprintf(' (%d lay outside the domain)', nAll-condN), '')), 'ok');
                    end
                elseif ~isempty(app.CondCB) && app.CondCB.Value
                    % --- conditioning on a mapped trace map ----------------
                    sec0 = app.sectionGeometry(rgn);
                    T = app.traceMapFor(sec0);
                    app.TraceMap = T;
                    if isempty(T)
                        app.log('Conditioning is on but the trace map is empty.','warn');
                    else
                        app.checkMapFitsFace(T, sec0);
                        % the mapped face is exhaustive within its window, so a
                        % stochastic fracture may not add a trace the map does
                        % not show; drop those before inserting the real ones
                        if app.CondExclCB.Value
                            bad = app.crossesFace(fnm, sec0);
                            fnm = fnm(~bad); sid = sid(~bad);
                            app.log(sprintf(['Mapped face is complete: dropped %d ' ...
                                'stochastic fractures that would have cut it.'], sum(bad)));
                        end
                        [CP, csid, crep] = app.conditionOnTraces(T, sec0, D);
                        CP = app.cleanPolys(Clip(CP, bbx));
                        fnm = [CP; fnm]; sid = [csid(1:numel(CP)); sid];
                        condN = numel(CP);
                        if crep.grown > 0
                            app.log(sprintf(['%d mapped traces were longer than ' ...
                                'their set''s L max; the size range was extended ' ...
                                'for those fractures.'], crep.grown), 'warn');
                        end
                        if crep.stray > 40
                            app.log(sprintf(['Conditioned fractures sit a ' ...
                                'median %.0f deg from their joint set''s mean ' ...
                                'pole. The traces are honoured, but no set in ' ...
                                'the table really produces this map - check ' ...
                                'the set orientations against the face.'], ...
                                crep.stray), 'warn');
                        end
                        if crep.coplanar > 0
                            % Almost always the joint set is oriented parallel
                            % to the section plane. A fracture parallel to the
                            % face cannot cut it, so no trace is possible.
                            app.log(sprintf(['%d of %d traces could not be ' ...
                                'honoured: the joint set is oriented parallel ' ...
                                'to the section plane, so a fracture from it ' ...
                                'cannot cut the face. Change the set''s Dip / ' ...
                                'DipDir, give it some scatter (dDip, dDDir), ' ...
                                'or turn the section plane.'], ...
                                crep.coplanar, size(T,1)), 'error');
                        end
                        if condN == 0
                            app.log(sprintf(['Conditioning produced nothing: ' ...
                                'none of the %d mapped traces could be given a ' ...
                                'fracture.'], size(T,1)), 'error');
                        elseif condN < size(T,1)
                            app.log(sprintf(['Conditioned on %d mapped traces -> ' ...
                                'only %d fractures honouring them.'], ...
                                size(T,1), condN), 'warn');
                        else
                            app.log(sprintf(['Conditioned on %d mapped traces -> %d ' ...
                                'fractures honouring them.'], size(T,1), condN), 'ok');
                        end
                    end
                end
                app.Model.condN = condN;
                [fnm, sid, ncond] = app.conditionNetwork(fnm, sid, ...
                    app.ASepField.Value, app.DSepField.Value);
                if ncond > 0
                    app.log(sprintf(['Conditional simulation rejected %d of %d ' ...
                        'fractures (pole sep %g deg, spacing %g).'], ncond, ...
                        ncond + numel(fnm), app.ASepField.Value, ...
                        app.DSepField.Value), 'warn');
                end
                app.Model.fnm = fnm; app.Model.setid = sid;
                app.Model.info = app.intensity3D(fnm, rgn);

                app.Model.mode = mode;
                app.Model.rgn  = rgn;
                app.Model.sets = D;
                app.Model.results = struct();
                app.computeSection();
                app.describeTraceMap();
                dt = toc(t0);

                app.refreshPlotTypes();
                app.refreshAnalyses();
                app.syncVars();
                app.describeModel(dt, sd);
                % The baseline is the DFN before this experiment started, so
                % it moves only while there is no experiment: no conditioning
                % in this build, and no fit standing in the table. Restore and
                % New are what release it again.
                if condN == 0 && ~app.FitApplied, app.captureBaseline(sd); end
                app.log(sprintf('Generated %s network: %d fractures in %.2f s (seed %d).', ...
                    mode, app.countFractures(), dt, sd), 'ok');
                app.renderPlot();
            catch ME
                app.log(['Generation failed: ' ME.message],'error');
                uialert(app.Fig, ME.message, 'Generation failed');
            end
        end

        function checkDomain(~, rgn)
            %CHECKDOMAIN  A rock mass has to have a size.
            %   Typing a min and a max the wrong way round was accepted in
            %   silence: the network came back with 0 fractures and no reason
            %   given. A zero-thickness domain was worse - it generated
            %   happily into a box of no volume, and then reported a P32,
            %   which is fracture area per unit volume, as though it meant
            %   something.
            ax = {'X','Y','Z'};
            for i = 1:3
                lo = rgn(2*i-1); hi = rgn(2*i);
                if ~(hi > lo)
                    error('ADFNE:BadDomain', ...
                        ['The rock mass runs from %g to %g in %s, so it has no ' ...
                         '%s extent and no volume.' newline newline 'Each min ' ...
                         'must be smaller than its max.'], lo, hi, ax{i}, ax{i});
                end
            end
        end

        function went = guideNoSets(app, why)
            %GUIDENOSETS  There are no joint sets: say what to do, and do it.
            %   Not an error - nothing failed, the user has not got there
            %   yet. A dialog whose buttons are the three ways forward, each
            %   of which takes you to the control in question.
            went = false;
            % 3D planes already loaded are the one kind of mapped data that
            % can build the table on its own, so offer that first
            havePlanes = app.is3DSource() && ...
                (strcmp(app.CondSrcDD.Value,'syn3') && ~isempty(app.PlaneSets) || ...
                 strcmp(app.CondSrcDD.Value,'file3') && ~isempty(app.PlanesLocal));
            msg = sprintf(['%s' newline newline ...
                'The joint-set table on the Model tab is empty. Ways to fill it:' newline ...
                '  -  Add a joint set, then type its dip, dip direction, count and size' newline ...
                '  -  Start from a preset (a typical rock mass) and edit it' newline ...
                '  -  Mapped 3D joint planes (Conditioning tab): FIT builds the table ' ...
                'from them - one set per set id in the file, or by clustering the poles' newline ...
                '  -  A mapped 2D trace map cannot build the table: a face does not carry ' ...
                'orientations. Add one row per joint set with its dip and dip direction, ' ...
                'and FIT fills in size and count.'], why);
            if app.QuietGuards
                app.log(strrep(msg, newline, ' '), 'warn'); return
            end
            if havePlanes
                opts = {'FIT the loaded planes', 'Add a joint set', 'Start from a preset', 'Cancel'};
            else
                opts = {'Add a joint set', 'Start from a preset', 'Load mapped data', 'Cancel'};
            end
            sel = uiconfirm(app.Fig, msg, 'No joint sets yet', 'Options', opts, ...
                'DefaultOption', 1, 'CancelOption', 4, 'Icon', 'info');
            tabs = app.TabGroup.Children;
            switch sel
                case 'FIT the loaded planes'
                    app.TabGroup.SelectedTab = tabs(2);
                    app.fitFromPlanes();
                    went = true;
                case 'Add a joint set'
                    app.TabGroup.SelectedTab = tabs(1);
                    app.onAddSet();
                    went = true;
                case 'Start from a preset'
                    app.TabGroup.SelectedTab = tabs(1);
                    try, focus(app.PresetDD); catch, end %#ok<CTCH>
                    app.log('Pick a preset from "Start from a preset", then edit it to suit.');
                    went = true;
                case 'Load mapped data'
                    app.TabGroup.SelectedTab = tabs(2);
                    app.log(['Conditioning tab: press "Import file..." for a mapped face or ' ...
                        'mapped 3D planes, or choose a synthetic source and fill its table.']);
                    went = true;
            end
        end

        function guideNoPlanesForBootstrap(app)
            %GUIDENOPLANESFORBOOTSTRAP  A bootstrap law with nothing to resample.
            msg = ['The bootstrap size law, orientation and aspect ratio resample ' ...
                'mapped 3D joint planes, and none are loaded.' newline newline ...
                'Import a planes file on the Conditioning tab, or choose another ' ...
                'law under Options / above the table.'];
            if app.QuietGuards, app.log(strrep(msg, newline, ' '), 'warn'); return, end
            sel = uiconfirm(app.Fig, msg, 'Nothing to resample', 'Options', ...
                {'Import a file', 'Cancel'}, 'DefaultOption', 1, 'CancelOption', 2, 'Icon','info');
            if strcmp(sel, 'Import a file'), app.onImportField(); end
        end

        function guideClippedBootstrap(app)
            %GUIDECLIPPEDBOOTSTRAP  Bootstrap sizes from planes declared clipped.
            msg = ['The bootstrap size law resamples the mapped planes'' sizes as they ' ...
                'are, and the band row says they are clipped at the faces - so they ' ...
                'are lower bounds, not sizes, and a model built on them would be too small.' ...
                newline newline 'Choose a parametric size law under Options (FIT corrects ' ...
                'those for the clip), or untick "clipped at faces" if the planes are complete.'];
            if app.QuietGuards, app.log(strrep(msg, newline, ' '), 'warn'); return, end
            uiconfirm(app.Fig, msg, 'Clipped sizes cannot be resampled', 'Options', {'OK'}, 'Icon','info');
        end

        function ok = guideNoSynthetic(app, what)
            %GUIDENOSYNTHETIC  The synthetic statistics table is empty.
            ok = false;
            msg = sprintf(['Source is synthetic, but the %s table is empty, so there is ' ...
                'nothing to draw.' newline newline 'Press "Add row" to add a family and ' ...
                'edit it, or "Import file..." to use mapped data instead.'], what);
            if app.QuietGuards, app.log(strrep(msg, newline, ' '), 'warn'); return, end
            sel = uiconfirm(app.Fig, msg, 'Nothing to draw yet', 'Options', ...
                {'Add a row', 'Import a file', 'Cancel'}, 'DefaultOption', 1, ...
                'CancelOption', 3, 'Icon', 'info');
            switch sel
                case 'Add a row',      app.onAddTraceSet();
                case 'Import a file',  app.onImportField();
            end
        end

        function out = iff(~, c, a, b)
            if c, out = a; else, out = b; end
        end

        function T = termination(app)
            %TERMINATION  Fraction of intersecting fractures cut back, 0..1.
            T = 0;
            if ~isempty(app.TermField) && isvalid(app.TermField), T = app.TermField.Value / 100; end
        end

        function tf = polysCross(app, A, B)
            %POLYSCROSS  Do two convex planar polygons actually intersect?
            %   Their planes meet in a line; each polygon meets the other's
            %   plane in a chord on that line; they intersect where the two
            %   chords overlap. Cheap, and exact for convex polygons.
            tf = false;
            nA = app.polyNormal(A); nB = app.polyNormal(B);
            cA = app.chordOnPlane(A, mean(B,1), nB);
            if isempty(cA), return, end
            cB = app.chordOnPlane(B, mean(A,1), nA);
            if isempty(cB), return, end
            L = cross(nA, nB); nl = norm(L);
            if nl < 1e-12, return, end            % parallel planes
            L = L / nl;
            a = sort(cA * L'); b = sort(cB * L');
            tf = a(1) <= b(2) && b(1) <= a(2);
        end

        function c = chordOnPlane(~, P, p0, n)
            %CHORDONPLANE  The two points where a convex polygon's edges cross
            %   the plane through p0 with normal n; empty if it does not.
            d = (P - p0) * n(:);
            m = size(P,1); c = zeros(0,3);
            for i = 1:m
                j = mod(i, m) + 1;
                if (d(i) > 0) ~= (d(j) > 0)
                    w = d(i) / (d(i) - d(j));
                    c(end+1,:) = P(i,:) + w*(P(j,:) - P(i,:)); %#ok<AGROW>
                end
            end
            if size(c,1) < 2, c = zeros(0,3); end
        end

        function [P, cut] = applyTermination(app, P)
            %APPLYTERMINATION  Enhanced Baecher: cut a share of the fractures
            %   that intersect an earlier one back to that one's plane.
            %
            %   In generation order - set 1 first, so the table's order is
            %   the age order - each fracture looks for earlier fractures it
            %   actually crosses (bounding boxes first, then the chord test).
            %   With probability T it is cut by the plane of one of them,
            %   chosen at random among those it crosses, keeping the side its
            %   own centre lies on; a cut that would leave nothing keeps the
            %   fracture whole instead. Everything else - centre, pole, size
            %   law, shape - has already been decided; this only takes away.
            T = app.termination();
            n = numel(P); cut = false(n,1);
            if T <= 0 || n < 2, return, end
            lo = zeros(n,3); hi = zeros(n,3);
            for i = 1:n, lo(i,:) = min(P{i},[],1); hi(i,:) = max(P{i},[],1); end
            for i = 2:n
                if rand >= T, continue, end
                q = P{i}; if size(q,1) < 3, continue, end
                j = find(all(lo(1:i-1,:) <= hi(i,:), 2) & all(hi(1:i-1,:) >= lo(i,:), 2));
                j = j(randperm(numel(j)));
                for kk = 1:numel(j)          % by index: 'for k = j'' runs once on an empty j
                    k = j(kk);
                    if ~app.polysCross(q, P{k}), continue, end
                    c = mean(q, 1);
                    nk = app.polyNormal(P{k}); pk = mean(P{k}, 1);
                    below = (c - pk) * nk(:) <= 0;
                    Q = app.clipHalfspace(q, pk, nk, below);
                    if size(Q,1) >= 3 && abs(polygonArea3d(Q)) > 1e-9
                        P{i} = Q; cut(i) = true;
                        lo(i,:) = min(Q,[],1); hi(i,:) = max(Q,[],1);
                    end
                    break
                end
            end
        end

        function m = centresModel(app)
            %CENTRESMODEL  'poisson' | 'nn' | 'levy'.
            m = 'poisson';
            if ~isempty(app.CentresDD) && isvalid(app.CentresDD), m = app.CentresDD.Value; end
        end

        function onCentresChanged(app)
            app.refreshEngineUI();
            app.refreshStateBar();
        end

        function C = drawCentres(app, n, sampler, diag)
            %DRAWCENTRES  n centres by the chosen model, inside a region that
            %   sampler(m) draws m uniform points from. diag is the region's
            %   size, which scales the models' one length.
            %
            %   uniform    the sampler itself.
            %   nn         sequential rejection: a candidate is kept with
            %              probability (d0/d)^b, d its distance to the nearest
            %              centre already placed, d0 = 2% of diag - so centres
            %              pile up around the first ones. Candidates come in
            %              batches judged against the centres placed so far,
            %              which is the same process up to the order within
            %              a batch. b = 0 is uniform.
            %   levy       a random walk: each centre is the last one plus a
            %              step of length s0 * u^(-1/D), Pareto with tail
            %              exponent D (the fractal dimension of the stops),
            %              s0 = 2% of diag, in a uniform direction; a step out
            %              of the region is redrawn, and after ten failures
            %              the walk restarts from a uniform point.
            model = app.centresModel();
            prm = 1.5;
            if ~isempty(app.ClusterField) && isvalid(app.ClusterField), prm = app.ClusterField.Value; end
            if n < 1, C = zeros(0,3); return, end
            switch model
                case 'nn'
                    b = max(prm, 0); d0 = 0.02 * diag;
                    C = zeros(n,3); k = 0; tries = 0;
                    C(1,:) = sampler(1); k = 1;
                    while k < n && tries < 500
                        m = min(4*(n-k) + 16, 1000);
                        cand = sampler(m);
                        if isempty(cand), tries = tries + 1; continue, end
                        d = sqrt(min(sum((permute(cand,[1 3 2]) - permute(C(1:k,:),[3 1 2])).^2, 3), [], 2));
                        keep = rand(m,1) < min(1, (d0 ./ max(d, 1e-12)).^b);
                        cand = cand(keep,:);
                        t = min(size(cand,1), n-k);
                        C(k+1:k+t,:) = cand(1:t,:); k = k + t; tries = tries + 1;
                    end
                    if k < n, C(k+1:n,:) = sampler(n-k); end   % never short-change the count
                case 'levy'
                    D = max(prm, 0.1); s0 = 0.02 * diag;
                    C = zeros(n,3); p = sampler(1); C(1,:) = p; fails = 0;
                    k = 1;
                    while k < n
                        L = s0 * rand^(-1/D);
                        v = randn(1,3); v = v / max(norm(v), eps);
                        q = p + L*v;
                        if app.inRegion(q, sampler)
                            k = k + 1; C(k,:) = q; p = q; fails = 0;
                        else
                            fails = fails + 1;
                            if fails > 10, p = sampler(1); k = k + 1; C(k,:) = p; fails = 0; end
                        end
                    end
                otherwise
                    C = sampler(n);
            end
        end

        function tf = inRegion(~, q, sampler)
            %INREGION  Whether q lies in the sampler's region: the sampler
            %   carries its own test as a second output when called with a
            %   point, so the two can never disagree.
            [~, tf] = sampler(q);
        end

        function P = placePolys(~, P, C)
            %PLACEPOLYS  Move each polygon so its centroid is C(i,:).
            for i = 1:min(numel(P), size(C,1))
                q = P{i}; if isempty(q), continue, end
                P{i} = q + (C(i,:) - mean(q, 1));
            end
        end

        function f = boxSampler(~, rgn)
            %BOXSAMPLER  Uniform points in the domain box, and the box test.
            lo = rgn([1 3 5]); hi = rgn([2 4 6]);
            f = @(x) boxDraw(x);
            function [pts, tf] = boxDraw(x)
                if isscalar(x)
                    pts = lo + (hi - lo) .* rand(x, 3); tf = true(x,1);
                else
                    pts = x; tf = all(x >= lo & x <= hi, 2);
                end
            end
        end

        function f = bandSampler(~, b)
            %BANDSAMPLER  Uniform points in the slab inside the box, and its test.
            rgn = b.rgn; lo = rgn([1 3 5]); hi = rgn([2 4 6]);
            pad = b.thk;
            f = @(x) bandDraw(x);
            function [pts, tf] = bandDraw(x)
                if isscalar(x)
                    pts = zeros(x,3); k = 0; tries = 0;
                    while k < x && tries < 200
                        m = 4*(x-k) + 16;
                        u = (b.box(1)-pad) + (b.box(2)-b.box(1)+2*pad)*rand(m,1);
                        v = (b.box(3)-pad) + (b.box(4)-b.box(3)+2*pad)*rand(m,1);
                        w = b.thk * (rand(m,1) - 0.5);
                        p = b.p0 + u.*b.e1 + v.*b.e2 + w.*b.n;
                        p = p(all(p >= lo & p <= hi, 2), :);
                        t = min(size(p,1), x-k);
                        pts(k+1:k+t,:) = p(1:t,:); k = k + t; tries = tries + 1;
                    end
                    pts = pts(1:k,:); tf = true(k,1);
                else
                    pts = x;
                    sd = (x - b.p0) * b.n(:);
                    tf = all(x >= lo & x <= hi, 2) & abs(sd) <= b.thk/2;
                end
            end
        end

        function m = orientModel(app)
            %ORIENTMODEL  'adfne' | 'fisher'.
            m = 'adfne';
            if ~isempty(app.OrientDD) && isvalid(app.OrientDD), m = app.OrientDD.Value; end
        end

        function onOrientModelChanged(app)
            %ONORIENTMODELCHANGED  Convert the scatter columns to the other
            %   model, as closely as the two allow, so the table keeps
            %   describing the same joint sets.
            app.harvestSets();
            D = app.Sets;
            was = app.LastOrient; now = app.orientModel(); app.LastOrient = now;
            for i = 1:size(D,1)
                % every model goes through one Fisher kappa: as much of a
                % scatter as any two of them share
                kF = app.scatterToFisher(was, D(i,:));
                [D(i,3), D(i,5)] = app.fisherToScatter(now, D(i,2), kF);
            end
            app.Sets = D;
            app.applyModeToTable();
            if app.is3DSource(), app.applyCondTableLayout(); end
            app.refreshStateBar();
        end

        function kF = scatterToFisher(app, model, row)
            %SCATTERTOFISHER  The Fisher kappa a row's scatter amounts to.
            dip = row(2); a = row(3); b = row(5);
            switch model
                case 'adfne',   kF = app.fisherFromAdfne(dip, a, b);
                case 'fisher',  kF = max(a, 0.5);
                case 'boot',    kF = 30;
                case 'bvn'      % two normal sds in degrees -> mean variance
                    va = deg2rad(max(a, 0.1))^2; vb = (deg2rad(max(b, 0.1)) * sind(max(dip, 1)))^2;
                    kF = 2 / (va + vb);
                case 'kent',    kF = max(a, 0.5);
                case 'bingham', kF = max(a, 0.05) + max(b, 0.05);   % 1/(2k) each way
                otherwise,      kF = 30;
            end
            kF = min(max(kF, 0.5), 1e4);
        end

        function [a, b] = fisherToScatter(app, model, dip, kF)
            %FISHERTOSCATTER  The two scatter columns that give a Fisher
            %   kappa's spread under the model, as far as it can.
            switch model
                case 'adfne',   [a, b] = app.adfneFromFisher(dip, kF);
                case 'fisher',  a = kF; b = 0;
                case 'boot',    a = 0;  b = 0;
                case 'bvn'
                    a = rad2deg(1/sqrt(kF));
                    b = rad2deg(1/sqrt(kF)) / sind(max(dip, 1));
                case 'kent',    a = kF; b = 0;
                case 'bingham', a = kF/2; b = kF/2;
                otherwise,      a = kF; b = 0;
            end
        end

        function [g1, g2, g3] = poleFrame(app, dip, ddir)
            %POLEFRAME  Mean pole, the strike direction, and down dip.
            g1 = app.planeNormal(dip, ddir);
            g2 = cross([0 0 1], g1);
            if norm(g2) < 1e-9, g2 = [1 0 0]; end
            g2 = g2 / norm(g2);
            g3 = cross(g1, g2);
        end

        function kF = fisherFromAdfne(app, dip, ddip, dddir)
            %FISHERFROMADFNE  One Fisher kappa standing in for two 1D scatters.
            %   A Fisher pole with concentration kappa moves about 1/sqrt(kappa)
            %   radians in any direction. The dip scatter moves it by the dip
            %   angle; the dip-direction scatter moves it by sin(dip) times
            %   the dip-direction angle. Match the mean of the two variances.
            kd = app.scatterKappa(ddip, true);
            kr = app.scatterKappa(dddir, false);
            vd = 1 / kd; vr = sind(max(dip, 1))^2 / kr;
            kF = 2 / max(vd + vr, 1e-12);
            kF = min(max(kF, 0.5), 1e4);
        end

        function [ddip, dddir] = adfneFromFisher(app, dip, kF)
            %ADFNEFROMFISHER  The two 1D scatters that give a Fisher kappa's
            %   spread in each direction: kappa itself along dip (in DFN's
            %   compressed convention), kappa sin^2(dip) along dip direction.
            kF = max(kF, 1e-6);
            ddip  = -app.dipKappaToTable(kF);
            dddir = -max(kF * sind(max(dip, 1))^2, 0.1);
        end

        function k = scatterKappa(app, v, isDip)
            %SCATTERKAPPA  The plain von Mises kappa a table scatter acts as.
            if v < 0
                k = -v;
                if isDip, k = app.dipKappaFromTable(k); end
            elseif v == 0
                k = 1e6;
            else
                k = 1 / deg2rad(v)^2;              % uniform +/- v degrees
            end
        end

        function N = drawFisherPoles(~, n, dip, ddir, kappa)
            %DRAWFISHERPOLES  n unit poles from a von Mises-Fisher distribution
            %   about the pole of (dip, ddir), by inverse CDF of the angular
            %   deviation - exact, no rejection - and a uniform azimuth.
            mu = [sind(dip)*cosd(ddir), sind(dip)*sind(ddir), cosd(dip)];
            u = rand(n,1);
            if kappa > 1e-9
                ct = 1 + log(1 - u*(1 - exp(-2*kappa))) / kappa;   % cos(theta)
            else
                ct = 1 - 2*u;                                     % uniform on the sphere
            end
            ct = min(max(ct, -1), 1);
            st = sqrt(1 - ct.^2);
            ph = 2*pi*rand(n,1);
            % a frame around the mean pole
            a = [0 0 1]; if abs(dot(a, mu)) > 0.9, a = [1 0 0]; end
            e1 = cross(mu, a); e1 = e1/norm(e1); e2 = cross(mu, e1);
            N = ct*mu + (st.*cos(ph))*e1 + (st.*sin(ph))*e2;
        end

        function P = applyOrientation(app, P, row)
            %APPLYORIENTATION  Under the Fisher model, turn each polygon DFN
            %   built onto a pole drawn from the set's Fisher distribution:
            %   the smallest rotation about its own centre that carries its
            %   normal onto the new pole. Centres and sizes are untouched.
            %   Under ADFNE's model nothing is done.
            if isempty(P) || strcmp(app.orientModel(), 'adfne'), return, end
            N = app.drawPoles(numel(P), row);
            for i = 1:numel(P)
                q = P{i}; if size(q,1) < 3, continue, end
                c = mean(q, 1);
                n0 = app.polyNormal(q); n1 = N(i,:);
                if dot(n0, n1) < 0, n1 = -n1; end        % a pole is axial
                ax = cross(n0, n1); sa = norm(ax); ca = dot(n0, n1);
                if sa < 1e-12, continue, end
                ax = ax / sa;
                K = [0 -ax(3) ax(2); ax(3) 0 -ax(1); -ax(2) ax(1) 0];
                R = eye(3) + sa*K + (1 - ca)*(K*K);      % Rodrigues
                P{i} = c + (q - c) * R';
            end
        end

        function N = drawPoles(app, n, row)
            %DRAWPOLES  n unit poles for one set row under the Fisher or the
            %   bootstrap model. Bootstrap resamples the mapped poles of the
            %   set with replacement, signed into one hemisphere, and jitters
            %   each by a Fisher draw of concentration row(3) if that is > 0.
            switch app.orientModel()
                case 'boot'
                    M = app.mappedPolesForSet(row);
                    if isempty(M)
                        error('ADFNE:NoPlanes', ['The bootstrap orientation resamples ' ...
                            'mapped joint planes, and none are loaded. Import a planes ' ...
                            'file on the Conditioning tab, or choose another model.']);
                    end
                    m = app.meanAxis(num2cell(M, 2)');
                    M(M*m' < 0, :) = -M(M*m' < 0, :);
                    N = M(randi(size(M,1), n, 1), :);
                    kj = row(3);
                    if kj > 0
                        for k = 1:n
                            [dp, dd] = app.poleToDipDir(N(k,:));
                            N(k,:) = app.drawFisherPoles(1, dp, dd, kj);
                        end
                    end
                case 'bvn'
                    dp = row(2) + max(row(3), 0) * randn(n,1);
                    dd = row(4) + max(row(5), 0) * randn(n,1);
                    N = zeros(n,3);
                    for k = 1:n, N(k,:) = app.planeNormal(dp(k), dd(k)); end
                case 'kent'
                    N = app.drawKentPoles(n, row(2), row(4), row(3), row(5));
                case 'bingham'
                    N = app.drawBinghamPoles(n, row(2), row(4), row(3), row(5));
                otherwise
                    N = app.drawFisherPoles(n, row(2), row(4), row(3));
            end
        end

        function N = drawKentPoles(app, n, dip, ddir, kappa, beta)
            %DRAWKENTPOLES  Kent (1982) poles in the concentrated form: a
            %   bivariate normal in the tangent plane at the mean pole, with
            %   variances 1/(kappa - 2 beta) along the major axis and
            %   1/(kappa + 2 beta) along the minor, mapped back onto the
            %   sphere along geodesics. Positive beta puts the major axis
            %   along strike, negative down dip. Kent's own condition
            %   2 beta < kappa is enforced as |beta| <= 0.45 kappa.
            kappa = max(kappa, 0.5);
            beta = sign(beta) * min(abs(beta), 0.45*kappa);
            [g1, g2, g3] = app.poleFrame(dip, ddir);
            if beta < 0, [g2, g3] = deal(g3, g2); beta = -beta; end
            t2 = randn(n,1) / sqrt(kappa - 2*beta);
            t3 = randn(n,1) / sqrt(kappa + 2*beta);
            th = sqrt(t2.^2 + t3.^2);
            u = (t2 .* g2 + t3 .* g3) ./ max(th, 1e-12);
            N = cos(th) .* g1 + sin(th) .* u;
        end

        function N = drawBinghamPoles(app, n, dip, ddir, k1, k2)
            %DRAWBINGHAMPOLES  Bingham poles with density proportional to
            %   exp(-k1 s^2 - k2 d^2), s and d the components along strike
            %   and down dip. Exact: the angular-central-Gaussian rejection
            %   sampler of Kent, Ganeiber & Mardia (2013), which stays
            %   efficient at any concentration.
            k1 = max(k1, 0); k2 = max(k2, 0);
            [g1, g2, g3] = app.poleFrame(dip, ddir);
            lam = [0 k1 k2];                             % eigenvalues of A
            b = fzero(@(b) sum(1 ./ (b + 2*lam)) - 1, [1e-6, 1e6]);
            om = 1 + 2*lam/b;                            % Omega's eigenvalues
            M  = exp(-(3 - b)/2) * (3/b)^1.5;
            G  = [g1; g2; g3];                           % rows: the frame
            N = zeros(n,3); k = 0;
            while k < n
                m = 4*(n-k) + 16;
                y = randn(m,3) ./ sqrt(om);              % N(0, Omega^-1) in the frame
                x = y ./ sqrt(sum(y.^2, 2));             % ACG
                q = sum(x.^2 .* lam, 2);                 % x'Ax
                w = sum(x.^2 .* om, 2);                  % x'Omega x
                acc = rand(m,1) < exp(-q) .* w.^1.5 / M;
                x = x(acc,:);
                t = min(size(x,1), n-k);
                N(k+1:k+t,:) = x(1:t,:) * G; k = k + t;
            end
            N(N*g1' < 0, :) = -N(N*g1' < 0, :);          % a pole is axial
        end

        function [dip, ddir] = poleToDipDir(~, n)
            %POLETODIPDIR  Dip and dip direction of a unit pole, degrees.
            n = n(:)' / max(norm(n), eps);
            if n(3) < 0, n = -n; end
            dip = acosd(max(-1, min(1, n(3))));
            ddir = mod(atan2d(n(2), n(1)), 360);
        end

        function [a, b] = tangentScatter(app, model, N, dip, ddir, w)
            %TANGENTSCATTER  The two scatter parameters of a model from the
            %   poles' covariance in the tangent plane at the mean pole
            %   (geodesic coordinates along strike and down dip). Exact for
            %   the bivariate normal, the concentrated form for Kent and
            %   Bingham - the same form they are drawn in.
            [g1, g2, g3] = app.poleFrame(dip, ddir);
            c  = max(-1, min(1, N * g1'));
            th = acos(c);
            tp = N - c .* g1;                        % tangent components
            nt = sqrt(sum(tp.^2, 2));
            t  = (th ./ max(nt, 1e-12)) .* tp;       % geodesic coordinates
            t2 = t * g2'; t3 = t * g3';
            if nargin < 6 || isempty(w), w = ones(size(t2)); end
            w = w(:) / sum(w);
            mu2 = sum(w.*t2); mu3 = sum(w.*t3);
            d2 = t2 - mu2; d3 = t3 - mu3;
            f  = 1 / max(1 - sum(w.^2), 1e-12);
            C  = f * [sum(w.*d2.^2), sum(w.*d2.*d3); sum(w.*d2.*d3), sum(w.*d3.^2)];
            switch model
                case 'bvn'
                    a = rad2deg(sqrt(C(2,2)));                       % dip moves down dip
                    b = rad2deg(sqrt(C(1,1))) / sind(max(dip, 1));   % dipdir moves along strike
                case 'kent'
                    [V, E] = eig(C); [ev, ix] = sort(diag(E), 'descend');
                    vmaj = max(ev(1), 1e-12); vmin = max(ev(2), 1e-12);
                    a = (1/vmaj + 1/vmin) / 2;
                    b = (1/vmin - 1/vmaj) / 4;
                    if abs(V(2, ix(1))) > abs(V(1, ix(1))), b = -b; end   % major axis down dip
                case 'bingham'
                    a = 1 / (2 * max(C(1,1), 1e-12));
                    b = 1 / (2 * max(C(2,2), 1e-12));
                otherwise
                    a = 30; b = 0;
            end
        end

        function kappa = fisherKappa(~, N, w)
            %FISHERKAPPA  Maximum-likelihood concentration of a Fisher sample
            %   of unit poles: solve coth(k) - 1/k = Rbar (Fisher, Lewis &
            %   Embleton 1987), with their large-kappa closed form as fallback.
            %   Optionally weighted.
            n = size(N,1);
            if n < 2, kappa = 30; return, end
            if nargin < 3 || isempty(w), w = ones(n,1); end
            w = w(:) / sum(w);
            R = norm(sum(w .* N, 1));
            if R >= 1 - 1e-9, kappa = 1e4; return, end
            A = @(k) coth(k) - 1./k;
            try
                kappa = fzero(@(k) A(k) - R, [1e-3, 1e5]);
            catch
                kappa = (n - 1) / (n - n*R);
            end
            kappa = min(max(kappa, 0.5), 1e4);
        end

        function m = intensityMode(app)
            %INTENSITYMODE  'N' | 'P32': what column 1 of the table holds.
            m = 'N';
            if ~isempty(app.IntensityDD) && isvalid(app.IntensityDD), m = app.IntensityDD.Value; end
        end

        function onIntensityModeChanged(app)
            %ONINTENSITYMODECHANGED  Convert column 1 to the other quantity,
            %   so the table keeps describing the same rock mass.
            app.harvestSets();
            rgn = [app.RgnFields.Value];
            D = app.Sets;
            was = app.LastIntensity; now = app.intensityMode(); app.LastIntensity = now;
            if ~isempty(D) && all(rgn([2 4 6]) > rgn([1 3 5])) && ~strcmp(was, now)
                for i = 1:size(D,1)
                    n = D(i,1);
                    if ~strcmp(was, 'N'), n = app.countForIntensity(D(i,:), rgn, was); end
                    if strcmp(now, 'N'), D(i,1) = n;
                    else, D(i,1) = n * app.intensityRatio(D(i,:), rgn, now); end
                end
                app.Sets = D;
            end
            app.applyModeToTable();
            if app.is3DSource(), app.applyCondTableLayout(); end
            app.refreshStateBar();
        end

        function D = countsFor(app, D, rgn)
            %COUNTSFOR  The table with column 1 as the count the generator
            %   takes, whatever the table holds.
            if ~strcmp(app.intensityMode(), 'N')
                for i = 1:size(D,1), D(i,1) = app.countForIntensity(D(i,:), rgn, app.intensityMode()); end
            end
        end

        function D = intensitiesFor(app, D, rgn)
            %INTENSITIESFOR  Column 1 back from counts to what the table holds.
            m = app.intensityMode();
            if strcmp(m, 'N'), return, end
            for i = 1:size(D,1), D(i,1) = D(i,1) * app.intensityRatio(D(i,:), rgn, m); end
        end

        function p10 = p10ForNetwork(app, P, rgn, dir)
            %P10FORNETWORK  Fractures per unit length along lines parallel
            %   to dir through the domain: 120 lines through points uniform
            %   in the box (fixed seed), each clipped to the box; hits are
            %   the polygons a line pierces inside their outline.
            dir = dir(:)' / max(norm(dir), eps);
            lo = rgn([1 3 5]); hi = rgn([2 4 6]);
            st = rng; rng(2718); cl = onCleanup(@() rng(st)); %#ok<NASGU>
            K = 120; pts = lo + (hi - lo) .* rand(K, 3);
            % each line's segment inside the box
            len = zeros(K,1);
            for k = 1:K
                t1 = -inf; t2 = inf;
                for ax = 1:3
                    if abs(dir(ax)) > 1e-12
                        ta = (lo(ax) - pts(k,ax)) / dir(ax); tb = (hi(ax) - pts(k,ax)) / dir(ax);
                        t1 = max(t1, min(ta,tb)); t2 = min(t2, max(ta,tb));
                    end
                end
                len(k) = max(t2 - t1, 0);
            end
            hits = 0;
            for i = 1:numel(P)
                q = P{i}; if size(q,1) < 3, continue, end
                n = app.polyNormal(q); c = mean(q, 1);
                dn = dir * n';
                if abs(dn) < 1e-12, continue, end            % line in the plane
                t = ((c - pts) * n') / dn;                    % K x 1
                x = pts + t .* dir;                           % K x 3, on the plane
                e1 = q(1,:) - c; e1 = e1 - (e1*n')*n; e1 = e1 / max(norm(e1), eps);
                e2 = cross(n, e1);
                inside = inpolygon((x - c)*e1', (x - c)*e2', (q - c)*e1', (q - c)*e2');
                hits = hits + nnz(inside);
            end
            p10 = hits / max(sum(len), eps);
        end

        function v = intensityForCount(app, row, rgn, kind, n)
            %INTENSITYFORCOUNT  P32 or P10 one set row produces at count n,
            %   from one fixed-seed trial clipped to the domain.
            if nargin < 5, n = row(1); end
            n = max(1, round(n));
            st = rng; rng(4242); cl = onCleanup(@() rng(st)); %#ok<NASGU>
            row(1) = n;
            P = app.trialNetwork(row, rgn, 4242);
            switch kind
                case 'P10'
                    sec = app.sectionGeometry(rgn);
                    v = app.p10ForNetwork(P, rgn, sec.n);
                otherwise
                    a = 0; for i = 1:numel(P), a = a + abs(polygonArea3d(P{i})); end
                    v = a / max(prod(rgn([2 4 6]) - rgn([1 3 5])), eps);
            end
        end

        function n = countForIntensity(app, row, rgn, kind)
            %COUNTFORINTENSITY  The count that gives this set the intensity
            %   in column 1, of the given kind.
            target = row(1);
            if ~(target > 0), n = 0; return, end
            ratio = app.intensityRatio(row, rgn, kind);
            if ratio <= 0, n = 0; return, end
            n = max(1, round(target / ratio));
        end

        function ratio = intensityRatio(app, row, rgn, kind)
            %INTENSITYRATIO  Intensity per fracture for one set row, cached
            %   on everything the trial depends on. Both directions of every
            %   conversion use this one number, so round trips are exact.
            key = mat2str([row(2:end) rgn], 10);
            sh = app.shapeSpec();
            key = [kind '|' key '|' app.sizeLaw() '|' sh.kind '|' mat2str([sh.q sh.aspect sh.aspectSd]) ...
                   '|' sh.axis '|' app.orientModel() '|' app.centresModel() '|' num2str(app.termination())];
            if strcmp(kind, 'P10')
                key = [key '|' mat2str([app.SecDipF.Value app.SecDirF.Value])];
            end
            if isempty(app.P32Ratio), app.P32Ratio = containers.Map('KeyType','char','ValueType','double'); end
            if app.P32Ratio.isKey(key)
                ratio = app.P32Ratio(key);
            else
                ratio = app.intensityForCount(row, rgn, kind, 1500) / 1500;
                app.P32Ratio(key) = ratio;
            end
        end

        function p32 = p32ForCount(app, row, rgn, n)
            %P32FORCOUNT  intensityForCount for P32; kept by name.
            if nargin < 4, n = row(1); end
            p32 = app.intensityForCount(row, rgn, 'P32', n);
        end

        function n = countForP32(app, row, rgn)
            %COUNTFORP32  The count that gives this set the P32 in column 1.
            %   Clipped area is linear in the count, so one trial fixes the
            %   ratio P32 / N for the set's parameters. 1500 fractures put
            %   the ratio's sampling noise near 2% at about a second a set
            %   (400 was 6%, and the fixed seed happened to land 17% high
            %   there, which the built models then all inherited). The ratio depends on everything
            %   in the row but the count, on the domain, the size law and
            %   the shape - so it is cached on exactly those, and a second
            %   GENERATE with the same table costs nothing.
            n = app.countForIntensity(row, rgn, 'P32');
        end

        function ratio = p32Ratio(app, row, rgn)
            %P32RATIO  intensityRatio for P32; kept by name.
            ratio = app.intensityRatio(row, rgn, 'P32');
        end

        function onShapeChanged(app)
            app.refreshEngineUI();
            app.refreshStateBar();
        end

        function sh = shapeSpec(app)
            %SHAPESPEC  Everything the polygon builder needs, from Options.
            sh = struct('kind','c','q',24,'aspect',1,'aspectSd',0,'axis','strike','aspectLaw','logn');
            if ~isempty(app.ShapeDD) && isvalid(app.ShapeDD), sh.kind = app.ShapeDD.Value; end
            if ~isempty(app.FacetSpin) && isvalid(app.FacetSpin), sh.q = app.FacetSpin.Value; end
            if strcmp(sh.kind,'e')
                if ~isempty(app.AspectField) && isvalid(app.AspectField), sh.aspect = app.AspectField.Value; end
                if ~isempty(app.AspectSdField) && isvalid(app.AspectSdField), sh.aspectSd = app.AspectSdField.Value; end
                if ~isempty(app.AxisDD) && isvalid(app.AxisDD), sh.axis = app.AxisDD.Value; end
                if ~isempty(app.AspectLawDD) && isvalid(app.AspectLawDD), sh.aspectLaw = app.AspectLawDD.Value; end
            end
        end

        function r = drawAspect(app, n, sh)
            %DRAWASPECT  One aspect ratio per fracture. The chosen law is
            %   applied to the elongation x = aspect - 1 with the mean and
            %   spread from Options, so the ratio never falls below 1; the
            %   bootstrap resamples the mapped planes' own ratios.
            if strcmp(sh.aspectLaw, 'boot')
                pool = app.mappedAspects();
                if isempty(pool)
                    error('ADFNE:NoPlanes', ['The bootstrap aspect ratio resamples mapped ' ...
                        'joint planes, and none are loaded. Import a planes file on the ' ...
                        'Conditioning tab, or choose another aspect law.']);
                end
                r = pool(randi(numel(pool), n, 1)); return
            end
            m = sh.aspect - 1; sd = sh.aspectSd;
            if sd <= 0 || m <= 0 || strcmp(sh.aspectLaw, 'const')
                r = sh.aspect * ones(n,1); return
            end
            r = 1 + app.drawLaw(n, sh.aspectLaw, m, sd);
        end

        function x = drawLaw(~, n, law, m, sd)
            %DRAWLAW  n draws >= 0 from a law given by its mean and standard
            %   deviation: uniform (cut at 0), normal (cut at 0), log-normal,
            %   Weibull (shape from the coefficient of variation) or gamma.
            u = rand(n,1);
            switch law
                case 'unif'
                    h = sqrt(3)*sd; lo = max(m - h, 0); hi = m + h;
                    x = lo + (hi - lo)*u;
                case 'norm'
                    Phi = @(z) 0.5*erfc(-z/sqrt(2));
                    Fa = Phi(-m/sd);
                    x = m + sd*sqrt(2)*erfinv(2*(Fa + (1-Fa)*u) - 1);
                case 'weib'
                    cv = sd/m;
                    g = @(k) sqrt(max(gamma(1+2/k)/gamma(1+1/k)^2 - 1, 0)) - cv;
                    try, k = fzero(g, [0.2 50]); catch, k = 2; end %#ok<CTCH>
                    lam = m / gamma(1 + 1/k);
                    x = lam * (-log(1 - u)).^(1/k);
                case 'gam'
                    k = (m/sd)^2; th = m/k;
                    x = th * gammaincinv(u, k);
                otherwise                                   % log-normal
                    v = log(1 + (sd/m)^2);
                    x = exp(log(m) - v/2 + sqrt(v)*sqrt(2)*erfinv(2*u - 1));
            end
            x = max(x(:), 0);
        end

        function r = polyAspect(~, q)
            %POLYASPECT  Long over short axis of a planar polygon, from the
            %   principal axes of its corners.
            d = q - mean(q, 1);
            ev = sort(eig(d' * d), 'descend');
            r = sqrt(ev(1) / max(ev(2), eps));
        end

        function a = mappedAspects(app)
            %MAPPEDASPECTS  Aspect ratios of the loaded 3D planes, if any.
            a = [];
            P = app.PlanesLocal;
            if isempty(P), return, end
            a = cellfun(@(q) app.polyAspect(q), P(:));
        end

        function P = shapePoly(~, c, n, d, q, aspect, axisMode, spin)
            %SHAPEPOLY  A q-gon of long-axis diameter d, centred at c with
            %   normal n, squashed to the aspect ratio across the long axis.
            %   The long axis lies along strike (horizontal in the plane),
            %   down dip, or at the given spin angle from strike.
            n = n(:)' / max(norm(n), eps);
            e1 = cross([0 0 1], n);
            if norm(e1) < 1e-9, e1 = [1 0 0]; end          % a horizontal plane
            e1 = e1 / norm(e1); e2 = cross(n, e1);
            switch axisMode
                case 'dip',    phi = pi/2;
                case 'random', phi = spin;
                otherwise,     phi = 0;
            end
            u = cos(phi)*e1 + sin(phi)*e2; v = cross(n, u);
            A = d/2; B = A / max(aspect, 1);
            t = (0:q-1)' * 2*pi/q;
            P = c(:)' + A*cos(t)*u + B*sin(t)*v;
        end

        function P = applyShape(app, P)
            %APPLYSHAPE  Rebuild DFN's polygons as elongated q-gons.
            %   Only for the elongated shape: DFN's own ellipse is a fixed
            %   2:1 along strike, and this replaces it with the aspect ratio,
            %   spread and long-axis direction from Options, at the same
            %   centre, in the same plane, at the same long-axis diameter -
            %   taken as twice the longest central ray, which is the radius
            %   for a regular polygon and the semi-major for an ellipse. The
            %   other shapes are left exactly as DFN built them.
            sh = app.shapeSpec();
            if ~strcmp(sh.kind,'e') || isempty(P), return, end
            r = app.drawAspect(numel(P), sh);
            spin = 2*pi*rand(numel(P),1);
            for i = 1:numel(P)
                q = P{i}; if size(q,1) < 3, continue, end
                c = mean(q, 1);
                d = 2 * max(sqrt(sum((q - c).^2, 2)));
                P{i} = app.shapePoly(c, app.polyNormal(q), d, sh.q, r(i), sh.axis, spin(i));
            end
        end

        function k = shapeSizeRatio(app)
            %SHAPESIZERATIO  Size3D of a unit-diameter polygon of the current
            %   shape. Size3D is twice the MEAN central ray, so for an
            %   elongated polygon it reads below the long-axis diameter the
            %   generator was given; the fit divides by this to write the
            %   diameter the generator expects.
            sh = app.shapeSpec();
            k = 1;
            if strcmp(sh.kind,'e')
                k = Size3D({app.shapePoly([0 0 0], [0 0 1], 1, sh.q, sh.aspect, 'strike', 0)});
            end
        end

        function law = sizeLaw(app)
            %SIZELAW  'exp' | 'logn' | 'pow', from the Options dropdown.
            law = 'exp';
            if ~isempty(app.SizeLawDD) && isvalid(app.SizeLawDD), law = app.SizeLawDD.Value; end
        end

        function onSizeLawChanged(app)
            %ONSIZELAWCHANGED  Say what Lp now means, fill it where it is zero.
            app.harvestSets();
            app.applyModeToTable();
            if app.is3DSource() || strcmp(app.CondSrcDD.Value, 'syn')
                if ~app.is3DSource() && ~isempty(app.TraceSets)
                    z = app.TraceSets(:,7) <= 0;
                    if any(z)
                        lp = app.defaultLp(app.traceRowsAsSets(app.TraceSets));
                        app.TraceSets(z,7) = lp(z);
                    end
                end
                app.applyCondTableLayout();
            end
            if ~isempty(app.Sets)
                z = app.Sets(:,9) <= 0;
                if any(z)
                    lp = app.defaultLp(app.Sets);
                    app.Sets(z,9) = lp(z);
                    app.applyModeToTable();
                end
            end
            app.refreshStateBar();
        end

        function sz = drawSizes(app, n, row, lo, hi)
            %DRAWSIZES  n fracture sizes for one set row, from the chosen law,
            %   truncated to [lo, hi] (the row's Lmin..Lmax unless told).
            %   Inverse-CDF sampling in every case, so truncation is exact
            %   and the draw costs nothing to reject.
            if nargin < 4 || isempty(lo), lo = row(6); end
            if nargin < 5 || isempty(hi), hi = row(8); end
            if hi < lo, hi = lo; end
            u = rand(n,1);
            switch app.sizeLaw()
                case 'logn'
                    m = max(row(7), 1e-12); sd = max(row(9), 1e-9*m);
                    v  = log(1 + (sd/m)^2);
                    mu = log(m) - v/2; sg = sqrt(v);
                    Phi = @(x) 0.5*erfc(-x/sqrt(2));
                    Fa = Phi((log(max(lo,1e-300)) - mu)/sg); Fb = Phi((log(hi) - mu)/sg);
                    if Fb <= Fa, sz = lo*ones(n,1); return, end
                    sz = exp(mu + sg*sqrt(2)*erfinv(2*(Fa + (Fb-Fa)*u) - 1));
                case 'pow'
                    al = row(9); if al <= 0, al = 2.5; end
                    a = max(lo, 1e-6*hi);
                    if abs(al - 1) < 1e-9
                        sz = a * (hi/a).^u;
                    else
                        t = 1 - al;
                        sz = (a^t + u*(hi^t - a^t)).^(1/t);
                    end
                case 'unif'
                    sz = lo + (hi - lo) * u;
                case 'norm'
                    m = row(7); sd = max(row(9), 1e-9*max(m,1));
                    Phi = @(x) 0.5*erfc(-x/sqrt(2));
                    Fa = Phi((lo - m)/sd); Fb = Phi((hi - m)/sd);
                    if Fb <= Fa, sz = lo*ones(n,1); return, end
                    sz = m + sd*sqrt(2)*erfinv(2*(Fa + (Fb-Fa)*u) - 1);
                case 'weib'
                    k = max(row(9), 0.05); lam = max(row(7), 1e-12) / gamma(1 + 1/k);
                    F = @(x) 1 - exp(-(x/lam).^k);
                    Fa = F(max(lo,0)); Fb = F(hi);
                    if Fb <= Fa, sz = lo*ones(n,1); return, end
                    sz = lam * (-log(1 - (Fa + (Fb-Fa)*u))).^(1/k);
                case 'gam'
                    k = max(row(9), 0.05); th = max(row(7), 1e-12) / k;
                    Fa = gammainc(max(lo,0)/th, k); Fb = gammainc(hi/th, k);
                    if Fb <= Fa, sz = lo*ones(n,1); return, end
                    sz = th * gammaincinv(Fa + (Fb-Fa)*u, k);
                case 'boot'
                    pool = app.mappedSizesForSet(row);
                    if isempty(pool)
                        error('ADFNE:NoPlanes', ['The bootstrap size law resamples ' ...
                            'mapped joint planes, and none are loaded. Import a ' ...
                            'planes file on the Conditioning tab, or choose another law.']);
                    end
                    if app.bandClips()
                        error('ADFNE:ClippedBootstrap', ['The bootstrap size law resamples ' ...
                            'the mapped planes'' sizes as they are, and the band row says ' ...
                            'they are clipped at the faces - lower bounds, not sizes. ' ...
                            'Choose a parametric size law (FIT corrects those for the ' ...
                            'clip), or untick "clipped at faces" if the planes are complete.']);
                    end
                    sz = pool(randi(numel(pool), n, 1));
                otherwise
                    sz = Rand(n, 'fun','exp', 'mu',row(7), 'ab',[lo hi]);
            end
            sz = min(max(sz(:), lo), hi);
        end

        function [P, sid] = mappedPlanesAssigned(app)
            %MAPPEDPLANESASSIGNED  The loaded 3D planes and the set each one
            %   belongs to, for the two bootstraps. Empty if none are loaded.
            P = app.PlanesLocal; sid = [];
            if isempty(P), return, end
            app.harvestSets();
            if isempty(app.Sets), sid = ones(numel(P),1); return, end
            sid = app.setsForPlanes(P, app.PlanesSid, app.Sets);
        end

        function pool = mappedSizesForSet(app, row)
            %MAPPEDSIZESFORSET  Sizes of the mapped planes assigned to this
            %   row's set; all of them if the set has none of its own.
            pool = [];
            [P, sid] = app.mappedPlanesAssigned();
            if isempty(P), return, end
            i = app.rowIndex(row);
            f = find(sid == i); if isempty(f), f = 1:numel(P); end
            pool = Size3D(P(f));
        end

        function N = mappedPolesForSet(app, row)
            %MAPPEDPOLESFORSET  Unit poles of the mapped planes assigned to
            %   this row's set, all if it has none; empty if none loaded.
            N = zeros(0,3);
            [P, sid] = app.mappedPlanesAssigned();
            if isempty(P), return, end
            i = app.rowIndex(row);
            f = find(sid == i); if isempty(f), f = 1:numel(P); end
            N = zeros(numel(f),3);
            for k = 1:numel(f), N(k,:) = app.polyNormal(P{f(k)}); end
        end

        function i = rowIndex(app, row)
            %ROWINDEX  Which table row this is: matched on the columns that
            %   identify a set (orientation and sizes), so a row handed in
            %   with its count converted to a P32 still finds itself.
            i = 1;
            if isempty(app.Sets), return, end
            d = sum(abs(app.Sets(:,2:9) - row(2:9)), 2);
            [~, i] = min(d);
        end

        function P = applySizeLaw(app, P, row)
            %APPLYSIZELAW  Rescale DFN's polygons to sizes from the chosen law.
            %   DFN draws exponential sizes and nothing else; rather than
            %   rebuild its polygons, each one is scaled about its centre to
            %   a size drawn here. Centres, orientations and shapes stay
            %   exactly DFN's. The exponential is left alone, so an existing
            %   session rebuilds fracture for fracture.
            if strcmp(app.sizeLaw(), 'exp') || isempty(P), return, end
            old = Size3D(P);
            new = app.drawSizes(numel(P), row);
            for i = 1:numel(P)
                if old(i) <= 0, continue, end
                c = mean(P{i}, 1);
                P{i} = c + (P{i} - c) * (new(i) / old(i));
            end
        end

        function n = countFractures(app)
            if iscell(app.Model.fnm), n = numel(app.Model.fnm);
            else, n = size(app.Model.fnm,1); end
        end

        function describeModel(app, dt, sd)
            % The persistent state bar replaces the old tab-local information
            % box. Keep the facts with the model so saved sessions preserve
            % what was actually built rather than borrowing today's controls.
            app.Model.build = struct( ...
                'seed',sd, ...
                'seconds',dt, ...
                'conditioning',app.conditioningSummary(), ...
                'signature',app.generativeSignature());
            app.refreshStateBar();
        end

        function summary = conditioningSummary(app)
            summary = 'unconditioned';
            if isempty(app.CondCB) || ~isvalid(app.CondCB) || ~app.CondCB.Value
                return
            end
            if app.is3DSource()
                n = 0;
                if isfield(app.Model,'condN'), n = app.Model.condN; end
                thk = app.BandThkF.Value;
                if strcmp(app.CondSrcDD.Value,'file3')
                    source = app.PlanesFileName;
                    if isempty(source), source = 'imported planes'; end
                else
                    source = 'synthetic planes';
                end
                summary = sprintf('%s, %d in a band %.3g thick', source, n, thk);
                return
            end
            n = size(app.TraceMap,1);
            if strcmp(app.CondSrcDD.Value,'file')
                source = app.CondFileName;
                if isempty(source), source = 'imported map'; end
            else
                source = 'synthetic map';
            end
            summary = sprintf('%s, %d traces', source, n);
        end

        function signature = generativeSignature(app)
            %GENERATIVESIGNATURE  Fingerprint everything that changes GENERATE.
            % Section plane, clip, view mode, analyses, Flow and Plots are
            % intentionally absent: changing how the model is viewed must
            % never make a valid rock mass appear stale.
            signature = '';
            if isempty(app.RgnFields) || isempty(app.SetTable) || ...
                    ~all(isvalid(app.RgnFields)) || ~isvalid(app.SetTable)
                return
            end
            state = struct();
            state.domain = [app.RgnFields.Value];
            state.sets = app.SetTable.Data;
            state.seed = app.SeedSpin.Value;
            state.randomise = app.RandSeedCB.Value;
            state.shape = app.ShapeDD.Value;
            state.facets = app.FacetSpin.Value;
            state.sizeLaw = app.sizeLaw();
            state.shapeSpec = app.shapeSpec();
            state.intensity = app.intensityMode();
            state.orientation = app.orientModel();
            state.centres = app.centresModel();
            state.cluster = app.ClusterField.Value;
            state.termination = app.termination();
            if strcmp(app.sizeLaw(),'boot') || strcmp(app.orientModel(),'boot') || strcmp(app.shapeSpec().aspectLaw,'boot')
                state.bootPlanes = numel(app.PlanesLocal);
                state.bootSum = sum(cellfun(@(q) sum(q(:)), app.PlanesLocal));
            end
            state.poleSeparation = app.ASepField.Value;
            state.minimumSpacing = app.DSepField.Value;

            state.conditioning = struct('enabled',false);
            if ~isempty(app.CondCB) && isvalid(app.CondCB)
                state.conditioning.enabled = app.CondCB.Value;
                if app.CondCB.Value
                    state.conditioning.source = app.CondSrcDD.Value;
                    state.conditioning.excludeUnmapped = app.CondExclCB.Value;
                    state.conditioning.set = app.CondSetDD.Value;
                    switch app.CondSrcDD.Value
                        case 'file'
                            state.conditioning.traces = app.TraceMap;
                            state.conditioning.traceSets = app.TraceSid;
                        case 'syn'
                            state.conditioning.traceStatistics = app.TraceSets;
                        case 'file3'
                            % a digest, not the planes: enough to notice a
                            % different file, small enough to hash every time
                            state.conditioning.planes = numel(app.PlanesLocal);
                            state.conditioning.planeSum = sum(cellfun(@(q) sum(q(:)), app.PlanesLocal));
                            state.conditioning.planeSets = app.PlanesSid;
                            state.conditioning.band = app.BandThkF.Value;
                        otherwise
                            state.conditioning.planeStatistics = app.PlaneSets;
                            state.conditioning.band = app.BandThkF.Value;
                            state.conditioning.bandCuts = app.bandCuts();
                            state.conditioning.bandClips = app.bandClips();
                    end
                end
            end

            payload = jsonencode(state);
            digest = java.security.MessageDigest.getInstance('SHA-256');
            digest.update(uint8(unicode2native(payload,'UTF-8')));
            bytes = typecast(digest.digest(),'uint8');
            signature = lower(reshape(dec2hex(bytes,2).',1,[]));
        end

        function refreshStateBar(app)
            if isempty(app.StateBar) || ~isvalid(app.StateBar), return, end
            app.GenBtn.Enable = matlab.lang.OnOffSwitchState(app.HasR15);
            neutral = [0.925 0.935 0.945];
            bg = neutral; fg = [0.30 0.34 0.38];

            if ~app.HasR15
                text = 'NO GENERATOR  |  ADFNE 1.5 is required.';
            elseif ~isfield(app.Model,'fnm') || isempty(app.Model.fnm)
                text = 'NO MODEL  |  Set the rock-mass parameters, then generate.';
            else
                m = app.Model;
                n = app.countFractures();
                dims = [m.rgn(2)-m.rgn(1), m.rgn(4)-m.rgn(3), ...
                        m.rgn(6)-m.rgn(5)];
                p32 = NaN;
                if isfield(m,'info') && isfield(m.info,'P32_clipped')
                    p32 = m.info.P32_clipped;
                end
                seed = app.SeedSpin.Value;
                if isfield(m,'build')
                    b = m.build;
                    seconds = NaN;
                    conditioning = 'build details unavailable';
                    if isfield(b,'seed'), seed = b.seed; end
                    if isfield(b,'seconds'), seconds = b.seconds; end
                    if isfield(b,'conditioning'), conditioning = b.conditioning; end
                    if isfield(b,'signature') && ...
                            strcmp(b.signature,app.generativeSignature())
                        status = 'MODEL CURRENT';
                        bg = [0.900 0.958 0.916]; fg = app.OK_COL;
                    else
                        status = 'MODEL OUT OF DATE';
                        bg = [1.000 0.958 0.855]; fg = app.WARN_COL;
                    end
                    more = '';
                    if isfield(m,'info') && isfield(m.info,'P10_normal') && isfinite(m.info.P10_normal)
                        more = sprintf('  |  P10 %.3g', m.info.P10_normal);
                    end
                    if isfield(m,'info') && isfield(m.info,'P33') && m.info.P33 > 0
                        more = [more sprintf('  |  P33 %.2g', m.info.P33)];
                    end
                    text = sprintf(['%s  |  %d fractures  |  seed %g  |  P32 %.3g%s  |  ' ...
                        'domain %gx%gx%g  |  %s  |  built %.2f s'], ...
                        status,n,seed,p32,more,dims,conditioning,seconds);
                else
                    text = sprintf(['MODEL LOADED  |  %d fractures  |  seed %g  |  ' ...
                        'P32 %.3g  |  domain %gx%gx%g  |  build details unavailable'], ...
                        n,seed,p32,dims);
                end
            end
            app.StateBar.BackgroundColor = bg;
            app.StateFactsLbl.Parent.BackgroundColor = bg;
            app.StateFactsLbl.Text = text;
            app.StateFactsLbl.FontColor = fg;
        end

        function bbx = bbx15(~, rgn, dim)
            %BBX15  ADFNE 1.0 stores the domain as [x1 x2 y1 y2 z1 z2]; 1.5 wants
            %   the two corners instead: [x1 y1 x2 y2] in 2D, [x1 y1 z1 x2 y2 z2]
            %   in 3D. Getting this wrong silently clips against the wrong box.
            if dim == 2
                bbx = [rgn(1) rgn(3) rgn(2) rgn(4)];
            else
                bbx = [rgn(1) rgn(3) rgn(5) rgn(2) rgn(4) rgn(6)];
            end
        end

        function dd = kappaToDdir(~, kappa)
            %KAPPATODDIR  DFN reads a negative 'ddir' as a Fisher kappa, but an
            %   exact 0 as "put every fracture on the mean direction". A user
            %   asking for kappa 0 means omnidirectional, which is the kappa -> 0
            %   limit, so send a tiny negative rather than zero.
            if kappa > 0, dd = -kappa; else, dd = -1e-7; end
        end

        function [P, sid, nrej] = conditionNetwork(app, P, sid, asep, dsep)
            %CONDITIONNETWORK  Conditional simulation, in 3D.
            %   ADFNE 1.5 offers asep/dsep only for its 2D generator, as a
            %   rejection rule applied while drawing fractures. That rule cannot
            %   be recovered by sectioning a 3D model - nothing would have
            %   enforced it - and a constraint satisfied on one section plane
            %   need not hold on another. So it is imposed here, in 3D, where it
            %   is a property of the rock mass:
            %
            %     asep  reject a fracture whose POLE lies within asep degrees of
            %           an already accepted one (orientation diversity)
            %     dsep  reject a fracture whose CENTRE lies within dsep of an
            %           already accepted one (minimum spacing)
            %
            %   Candidates are independent draws, so accepting greedily in order
            %   is the same process as sequential rejection sampling.
            nrej = 0;
            if (asep <= 0 && dsep <= 0) || numel(P) < 2, return, end
            n = numel(P);
            cts = zeros(n,3); nrm = zeros(n,3);
            for i = 1:n
                cts(i,:) = mean(P{i}, 1);
                nrm(i,:) = app.polyNormal(P{i});
            end
            keep = false(n,1);
            ac = zeros(n,3); an = zeros(n,3); k = 0;
            ca = cosd(asep);
            for i = 1:n
                ok = true;
                if k > 0
                    if dsep > 0
                        dd = sum((ac(1:k,:) - cts(i,:)).^2, 2);
                        if any(dd < dsep^2), ok = false; end
                    end
                    if ok && asep > 0
                        % poles are bidirectional, so compare |cos|
                        cc = abs(an(1:k,:) * nrm(i,:)');
                        if any(cc > ca), ok = false; end
                    end
                end
                if ok
                    k = k + 1; ac(k,:) = cts(i,:); an(k,:) = nrm(i,:);
                    keep(i) = true;
                end
            end
            nrej = sum(~keep);
            P = P(keep);
            if ~isempty(sid), sid = sid(keep); end
        end

        function u = polyNormal(~, q)
            %POLYNORMAL  Unit normal of a planar polygon (Newell's method).
            u = [0 0 1];
            if size(q,1) < 3, return, end
            r = circshift(q, -1, 1);
            u = [sum((q(:,2)-r(:,2)).*(q(:,3)+r(:,3))), ...
                 sum((q(:,3)-r(:,3)).*(q(:,1)+r(:,1))), ...
                 sum((q(:,1)-r(:,1)).*(q(:,2)+r(:,2)))];
            nu = norm(u);
            if nu < eps, u = [0 0 1]; else, u = u / nu; end
        end

        function st = traceStats(~, T, faceArea)
            %TRACESTATS  What a mapped face actually measures.
            %   meanL and P21 are the two standard measurables: mean trace
            %   length, and trace length per unit face area.
            st = struct('n',0,'meanL',NaN,'P21',NaN,'totalL',0);
            if isempty(T), return, end
            L = sqrt(sum((T(:,3:4)-T(:,1:2)).^2, 2));
            st.n = numel(L); st.totalL = sum(L); st.meanL = mean(L);
            if nargin > 2 && faceArea > 0, st.P21 = sum(L) / faceArea; end
        end

        function [win, a, cov] = mapWindow(app, T, sec)
            %MAPWINDOW  The part of the face the trace map actually covers.
            %   P21 is a length per unit AREA, so the area has to be the one
            %   that was mapped. Dividing a partial exposure by the whole
            %   section face understates it by exactly the area ratio, and the
            %   fitter then compensates by cutting the fracture count: a map
            %   over half the face fitted N at a third of the truth.
            %   checkMapFitsFace does not catch this - it asks how much of the
            %   MAP is on the face, which is the other direction entirely.
            bx = sec.box;
            if isempty(T)
                win = bx; a = app.faceArea(sec); cov = 1; return
            end
            u = [min(T(:,[1 3]),[],'all'), max(T(:,[1 3]),[],'all')];
            v = [min(T(:,[2 4]),[],'all'), max(T(:,[2 4]),[],'all')];
            win = [max(u(1),bx(1)), min(u(2),bx(2)), ...
                   max(v(1),bx(3)), min(v(2),bx(4))];
            a = max(win(2)-win(1), 0) * max(win(4)-win(3), 0);
            fa = app.faceArea(sec);
            if a <= 0 || ~isfinite(a), win = bx; a = fa; end
            cov = 1; if fa > 0, cov = a / fa; end
        end

        function a = faceArea(~, sec)
            a = 0;
            if isfield(sec,'faceUV') && size(sec.faceUV,1) >= 3
                a = abs(polygonArea(sec.faceUV));
            end
        end

        function P = trialNetwork(app, D, rgn, seed)
            %TRIALNETWORK  A stochastic network for the fitter.
            %   Deliberately skips conditioning and the face-exclusion rule: the
            %   fit is asking what statistics the set parameters produce on
            %   their own, not what a conditioned model looks like.
            rng(seed);
            bbx = app.bbx15(rgn, 3);
            shp = app.ShapeDD.Value;
            if strcmp(shp,'l'), shp = 'legacy'; end
            P = {};
            for i = 1:size(D,1)
                out = DFN('dim',3,'n',round(D(i,1)), ...
                          'dip',D(i,2),'ddip',D(i,3), ...
                          'dir',D(i,4),'ddir',D(i,5), ...
                          'minl',D(i,6),'mu',D(i,7),'maxl',D(i,8), ...
                          'shape',shp,'q',app.FacetSpin.Value, ...
                          'bbx',[0,0,0,1,1,1]);
                Q = app.applyShape(app.applyOrientation(app.applySizeLaw(out.Orig, D(i,:)), D(i,:)));
                if strcmp(app.centresModel(), 'poisson')
                    Q = app.spreadPolys3D(Q, rgn);
                else
                    dg = norm(rgn([2 4 6]) - rgn([1 3 5]));
                    Q = app.placePolys(Q, app.drawCentres(numel(Q), app.boxSampler(rgn), dg));
                end
                Q = app.cleanPolys(Clip(Q, bbx));
                P = [P; Q]; %#ok<AGROW>
            end
            P = app.applyTermination(P);
        end

        function st = forwardStats(app, D, rgn, sec, seeds, win)
            %FORWARDSTATS  Trace statistics this set table produces on the face.
            %   Averaged over a few realisations, but with FIXED seeds: common
            %   random numbers make the objective a deterministic function of
            %   the parameters, which is what lets a root-find work on it.
            %
            %   win is the window the target was measured over. The model has
            %   to be measured over the same one - both the area P21 divides
            %   by, and the edge truncation that shortens traces at its border
            %   - or the two numbers are not comparable.
            if nargin < 6 || isempty(win), win = sec.box; end
            ar = max(win(2)-win(1), 0) * max(win(4)-win(3), 0);
            if ar <= 0, ar = app.faceArea(sec); end
            nn = zeros(numel(seeds),1); ml = nn; pp = nn;
            for k = 1:numel(seeds)
                P = app.trialNetwork(D, rgn, seeds(k));
                L3 = app.tracesOnPlane(P, sec);
                if isempty(L3)
                    nn(k) = 0; ml(k) = NaN; pp(k) = 0; continue
                end
                uv = [app.toPlaneUV(sec, L3(:,1:3)), app.toPlaneUV(sec, L3(:,4:6))];
                uv = Clip(uv, [win(1) win(3) win(2) win(4)]);
                if ~isempty(uv), uv(all(uv==0,2),:) = []; end
                if isempty(uv)
                    nn(k) = 0; ml(k) = NaN; pp(k) = 0; continue
                end
                t = app.traceStats(uv, ar);
                nn(k) = t.n; ml(k) = t.meanL; pp(k) = t.P21;
            end
            st = struct('n', mean(nn), 'meanL', mean(ml,'omitnan'), ...
                        'P21', mean(pp), 'nrel', numel(seeds), ...
                        'meanLsd', std(ml,'omitnan'), 'P21sd', std(pp));
        end

        function onFitSets(app)
            %ONFITSETS  Infer 3D set parameters from 2D trace statistics.
            %
            %   The method is the DFN industry's "simulated sampling"
            %   calibration: generate a trial network, sample it exactly as
            %   the field was sampled, compare, rescale. Stage 2 below is
            %   the P32-from-P21 rule stated in Rogers et al. (2017, eq. 2):
            %   P32_actual = P32_sim / P21_sim x P21_actual, iterated because
            %   the measurement is noisy. Stage 1 does by simulation what
            %   Warburton (1980) and Zhang, Einstein & Dershowitz (2002) do
            %   analytically for the Baecher disc: mean trace length is a
            %   monotone function of fracture size. The intensity measures
            %   are Dershowitz & Herda (1992); the window correction and the
            %   censoring caveat follow Mauldon (1998); fixed seeds are the
            %   common-random-numbers device of Glasserman & Yao (1992).
            %   Full references in README.md, "References".
            %
            %   Size and count only. Orientation is deliberately NOT fitted,
            %   and cannot be from one face - two separate degeneracies, both
            %   measured:
            %
            %   1. Mirror. Reflecting a pole in the face plane leaves
            %      cross(n,pole) unchanged, so the trace direction is
            %      identical, and it maps the pole-normal angle to its
            %      supplement, so sin() and the cut frequency are identical
            %      too. dip 60/dipdir 40 and dip 60/dipdir 140 are 83 deg
            %      apart and give 42 vs 44 traces, mean length 1.109 vs 1.174.
            %      A face cannot tell whether a joint dips into it or out of
            %      it - which is why a geologist reads that off the exposure,
            %      not off the trace map.
            %
            %   2. Count against obliquity. Trace count goes as N*D*sin(phi),
            %      and nothing else a face measures depends on phi: the chord
            %      length distribution of a disc is the same whatever the
            %      angle of the cut. So only the PRODUCT is observable.
            %      Holding N*sin(phi) at 900: phi 20 with N 2631 gives 112
            %      traces, meanL 1.335, P21 1.87; phi 90 with N 900 gives 115,
            %      1.306, 1.875. Indistinguishable.
            %
            %   The count stage below already extracts that product, so the
            %   fit is at the information limit of a single face. Recovering
            %   orientation needs a second, non-parallel face.
            if app.is3DSource(), app.fitFromPlanes(); return, end
            app.harvestSets();
            if isempty(app.Sets)
                app.guideNoSets(['FIT from a trace map adjusts the joint-set table, so ' ...
                    'it needs one row per set to fill in - with the dip and dip ' ...
                    'direction, which a face cannot supply. FIT then fits the sizes ' ...
                    'and counts. (Mapped 3D planes can build the table on their own.)']);
                return
            end
            app.harvestCondTable();
            if strcmp(app.CondSrcDD.Value,'syn') && isempty(app.TraceSets)
                app.guideNoSynthetic('trace statistics'); return
            end
            rgn0 = [app.RgnFields.Value];
            syn  = ~isempty(app.CondSrcDD) && strcmp(app.CondSrcDD.Value,'syn');
            if syn
                % draw the face the statistics describe, and fit to that. It
                % is one realisation of them, not the statistics themselves,
                % so the target carries the sampling noise of its own trace
                % count - which is the honest thing to fit against anyway.
                T = app.traceMapFor(app.sectionGeometry(rgn0), true);
                app.TraceMap = T;
                app.describeTraceMap();
                if ~isempty(T)
                    app.log(sprintf(['Fit target: %d traces drawn from the ' ...
                        'synthetic statistics table. Re-running FIT redraws ' ...
                        'them, so the answer will move a little.'], size(T,1)));
                end
            else
                T = app.TraceMap;
            end
            if isempty(T)
                if syn
                    msg = ['The synthetic statistics table produced no traces. ' ...
                           'Check N is at least 1 and the lengths are positive ' ...
                           'and within the face - or press "Add row" for a ' ...
                           'typical family.'];
                else
                    msg = ['No trace file loaded. Press "Import file…" to load ' ...
                           'a mapped face, or set Source to "synthetic from 2D ' ...
                           'statistics" to draw one from the table.'];
                end
                uialert(app.Fig, msg, 'No trace map'); return
            end
            cl = app.busy('Fitting: matching trace statistics…', true, 'fit'); %#ok<NASGU>
            try
                app.harvestSets();
                D0  = app.Sets;
                D0  = app.countsFor(D0, [app.RgnFields.Value]);   % fit in counts
                rgn = [app.RgnFields.Value];
                sec = app.sectionGeometry(rgn);
                [win, ar, cov] = app.mapWindow(T, sec);
                tgt = app.traceStats(T, ar);
                if cov < 0.85
                    app.log(sprintf(['Fit: the map covers %.0f%% of the face, ' ...
                        'so P21 is measured over the mapped window (%.4g x ' ...
                        '%.4g) rather than the whole face. Dividing by the ' ...
                        'whole face would understate P21 by %.2fx and the fit ' ...
                        'would cut the fracture count to match.'], 100*cov, ...
                        win(2)-win(1), win(4)-win(3), 1/max(cov,eps)), 'warn');
                end
                if ~isfinite(tgt.meanL) || tgt.n < 2
                    error('ADFNE:Target','The trace map has too few traces to fit.');
                end
                app.checkMapFitsFace(T, sec);
                seeds = 1000 + (1:5);        % common random numbers
                if tgt.n < 30
                    app.log(sprintf(['Fit: only %d traces to match. The target ' ...
                        'statistics are themselves noisy at that sample size, ' ...
                        'so treat the fitted values as indicative.'], tgt.n), 'warn');
                end

                % --- stage 1: size scale -> mean trace length ----------------
                % Mean trace length rises monotonically with fracture size and
                % is almost independent of fracture count, so this is a clean
                % 1D root find on a single scale factor applied to L min/mean/max.
                f = @(sc) app.fitResidual(D0, sc, rgn, sec, seeds, tgt.meanL, win);
                [sc, bracketed] = app.bisect(f, 0.25, 4, 0.01, 14);   % within 1% of target
                if ~bracketed
                    app.log(['Fit: the target mean trace length is outside what ' ...
                        'a 0.25x-4x size change can reach; taking the closer end.'],'warn');
                end
                D = D0; D(:,6:8) = D0(:,6:8) * sc;
                if any(strcmp(app.sizeLaw(),{'logn','norm'})), D(:,9) = D0(:,9) * sc; end

                % --- stage 2: count -> intensity ----------------------------
                % With size fixed, P21 is very nearly linear in N, so one
                % measured slope gives the multiplier directly.
                k = 1;
                for it = 1:5
                    st = app.forwardStats(D, rgn, sec, seeds, win);
                    if st.P21 <= 0 || ~isfinite(tgt.P21), break, end
                    step = tgt.P21 / st.P21;
                    if abs(step - 1) < 0.03, break, end      % within 3%
                    k = k * step;
                    D(:,1) = max(1, round(D0(:,1) * k));
                end
                fin = app.forwardStats(D, rgn, sec, seeds, win);

                D = app.intensitiesFor(D, rgn); D0 = app.intensitiesFor(D0, rgn);   % back to what the table holds
                app.Sets = D;
                app.applyModeToTable();
                app.refreshCondUI();
                app.showFitPreview(D0, D);
                app.CondInfo.Value = [app.CondInfo.Value; {''
                    '--- fit to these traces ---'
                    sprintf('measured over : %.4g x %.4g  (%.0f%% of the face)', ...
                            win(2)-win(1), win(4)-win(3), 100*cov)
                    sprintf('size scale    : x %.3f', sc)
                    sprintf('count scale   : x %.3f', k)
                    sprintf('%-14s %10s %10s', '', 'target', 'fitted')
                    sprintf('%-14s %10.4g %10.4g', 'mean trace L', tgt.meanL, fin.meanL)
                    sprintf('%-14s %10.4g %10.4g', 'P21', tgt.P21, fin.P21)
                    sprintf('%-14s %10d %10.0f', 'trace count', tgt.n, fin.n)
                    sprintf('spread over %d realisations: mean L +/- %.3g, P21 +/- %.3g', ...
                            fin.nrel, fin.meanLsd, fin.P21sd)
                    'Non-unique: other size distributions can give the same'
                    'trace statistics. Check the full length distribution, not'
                    'just the mean, before trusting the result.'}];
                % From here the joint-set table is the fitter's, not the
                % user's. The baseline must stop moving, or regenerating to
                % look at the fitted DFN -- the obvious next thing to do --
                % would quietly make the fitted model the thing "Restore
                % original DFN" restores.
                app.FitApplied = true;
                app.refreshRestoreBtn();
                app.log(sprintf(['Fit: size x%.3f, count x%.3f -> mean trace ' ...
                    '%.4g (target %.4g), P21 %.4g (target %.4g).'], sc, k, ...
                    fin.meanL, tgt.meanL, fin.P21, tgt.P21), 'ok');
            catch ME
                app.log(['Fit failed: ' ME.message],'error');
                uialert(app.Fig, ME.message, 'Fit failed');
            end
        end

        function showFitPreview(app, D0, D)
            %SHOWFITPREVIEW  What the fit just wrote into the Model tab.
            %   The fit changes the set table on another tab, so show the before
            %   and after here rather than leaving the user to go and look. Only
            %   count and size move - orientation is never touched by the fit.
            if isempty(app.FitTable), return, end
            n = size(D,1);
            rows = cell(n,5);
            for i = 1:n
                rows{i,1} = sprintf('%d', i);
                rows{i,2} = sprintf('%g', D0(i,1));
                rows{i,3} = sprintf('%g', D(i,1));
                rows{i,4} = sprintf('%.4g', D0(i,7));
                rows{i,5} = sprintf('%.4g', D(i,7));
            end
            app.FitTable.Data = rows;
            app.FitLbl.Text = ['Fitted joint sets  (already written to the ' ...
                'Model tab; orientation untouched)'];
        end

        function r = fitResidual(app, D0, sc, rgn, sec, seeds, targetMeanL, win)
            D = D0; D(:,6:8) = D0(:,6:8) * sc;
            if strcmp(app.sizeLaw(),'logn'), D(:,9) = D0(:,9) * sc; end
            st = app.forwardStats(D, rgn, sec, seeds, win);
            if ~isfinite(st.meanL), r = -1; return, end
            r = st.meanL / targetMeanL - 1;
        end

        function T = traceMapFor(app, sec, force)
            %TRACEMAPFOR  The trace map, in face (u,v) coordinates.
            %   force skips the "Condition the model on this map" gate. That
            %   gate belongs to generation, which must not condition unless
            %   asked - but the FIT button is step 2 and conditioning is step
            %   3, advertised as independent. Without force, a synthetic map
            %   could not be built for a fit at all: the fit read TraceMap,
            %   which only GENERATE fills, and only while conditioning is on.
            %   So Source = synthetic plus a filled table plus FIT reported
            %   "no trace map" and there was no way to get one.
            if nargin < 3, force = false; end
            T = zeros(0,4);
            if ~force && (isempty(app.CondCB) || ~app.CondCB.Value), return, end
            if strcmp(app.CondSrcDD.Value, 'file')
                T = app.TraceMap;
                return
            end
            % synthetic: ADFNE's own 2D generator, run inside the face outline.
            % This is where 2D generation earns its place - not as a rival model
            % but as a way to author a trace map for the 3D model to honour.
            % Seeded from the model seed, as the 3D band is, so FIT, GENERATE
            % and Compare all read the same lines - and a fit is repeatable.
            % The stream is put back afterwards so generation is unmoved.
            D = app.CondTable.Data;
            if isempty(D), return, end
            st = rng; rng(app.SeedSpin.Value + 7919); cl = onCleanup(@() rng(st)); %#ok<NASGU>
            box = sec.box;                              % [umin umax vmin vmax]
            cnd = {};
            if app.ASepField.Value > 0 || app.DSepField.Value > 0
                cnd = {'asep',app.ASepField.Value,'dsep',app.DSepField.Value,'mit',100};
            end
            D = app.padTraceSets(D);
            if ~strcmp(app.sizeLaw(), 'exp') && ~isempty(cnd)
                app.log(['Synthetic traces: asep/dsep are ADFNE''s own rejection ' ...
                    'rule, enforced while it draws exponential lengths; the size ' ...
                    'law is applied to those lines afterwards, about their centres, ' ...
                    'so dsep holds only approximately.'], 'warn');
            end
            for i = 1:size(D,1)
                out = DFN('dim',2,'n',round(D(i,1)), ...
                          'dir',D(i,2),'ddir',app.kappaToDdir(D(i,3)), ...
                          'minl',D(i,4),'mu',D(i,5),'maxl',D(i,6), ...
                          'bbx',[0,0,1,1], cnd{:});
                L = app.relengthLines(out.Orig, D(i,:));
                L = app.spreadLines2D(L, box);          % unit square -> the face
                L = Clip(L, [box(1) box(3) box(2) box(4)]);
                if ~isempty(L), L(all(L==0,2),:) = []; end
                T = [T; L]; %#ok<AGROW>
            end
        end

        function L = relengthLines(app, L, row)
            %RELENGTHLINES  Give each line a length from the chosen size law,
            %   kept about its own centre and direction. ADFNE's 2D generator
            %   draws only the truncated exponential; every other law is
            %   drawn here from the trace row's own Lmin/Lmean/Lmax/Lp, the
            %   bootstrap from the lengths of the imported trace map.
            if isempty(L) || strcmp(app.sizeLaw(), 'exp'), return, end
            n = size(L,1);
            if strcmp(app.sizeLaw(), 'boot')
                T = app.TraceMap;
                if isempty(T)
                    error('ADFNE:NoTraces', ['The bootstrap size law resamples the ' ...
                        'lengths of an imported trace map, and none is loaded. Import ' ...
                        'a trace map first, or choose another size law.']);
                end
                pool = hypot(T(:,3) - T(:,1), T(:,4) - T(:,2));
                len = pool(randi(numel(pool), n, 1));
            else
                len = app.drawSizes(n, app.traceRowsAsSets(row), row(4), row(6));
            end
            c = (L(:,1:2) + L(:,3:4)) / 2;
            d = L(:,3:4) - L(:,1:2);
            nd = hypot(d(:,1), d(:,2)); nd(nd == 0) = 1;
            u = d ./ nd;
            L = [c - u .* (len/2), c + u .* (len/2)];
        end

        function checkMapFitsFace(app, T, sec)
            %CHECKMAPFITSFACE  Is the trace map actually on the face?
            %   An imported map is in face coordinates, so it only means
            %   anything if the domain and section plane put the face where the
            %   map is. Get that wrong and every conditioned fracture is built
            %   outside the domain and clipped away, leaving a model that looks
            %   generated but honours nothing. That used to happen in silence.
            %
            %   Testing for overlap is not enough: the usual mistake leaves the
            %   default 1 m domain with an 8 m map, and a 1 m face sits INSIDE
            %   that map. What matters is how much of the map the face covers.
            bx = sec.box;
            u = [min(T(:,[1 3]),[],'all'), max(T(:,[1 3]),[],'all')];
            v = [min(T(:,[2 4]),[],'all'), max(T(:,[2 4]),[],'all')];
            spans = sprintf(['map  spans u %.4g to %.4g,  v %.4g to %.4g' newline ...
                             'face spans u %.4g to %.4g,  v %.4g to %.4g'], ...
                             u(1), u(2), v(1), v(2), bx(1), bx(2), bx(3), bx(4));
            ou = max(0, min(u(2),bx(2)) - max(u(1),bx(1)));
            ov = max(0, min(v(2),bx(4)) - max(v(1),bx(3)));
            amap = max(u(2)-u(1), eps) * max(v(2)-v(1), eps);
            frac = (ou * ov) / amap;               % of the map, on the face
            if frac < 0.05
                error('ADFNE:MapOffFace', ['%s' newline newline ...
                    'The face covers only %.0f%% of the trace map, so almost ' ...
                    'nothing can be conditioned.' newline newline ...
                    'Set the Model tab''s domain and section plane so the face ' ...
                    'covers the map. For the supplied examples that is domain ' ...
                    'X 0-10, Y 0-10, Z 0-8 with the section plane at dip 90, ' ...
                    'dipdir 0, offset 0.'], spans, 100*frac);
            elseif frac < 0.9
                app.log(sprintf(['Trace map: the face covers %.0f%% of it - ' ...
                    'traces beyond the face cannot be honoured.  %s'], ...
                    100*frac, strrep(spans, newline, '   |   ')), 'warn');
            end
        end

        function [P, sid, rep] = conditionOnTraces(app, T, sec, D)
            %CONDITIONONTRACES  A 3D fracture for every mapped trace.
            %   A trace constrains but does not determine its fracture: the
            %   fracture plane must contain the trace line, which leaves one
            %   free rotation about it. That angle is sampled from the joint
            %   set's own pole distribution restricted to the admissible great
            %   circle - for a Fisher set that conditional is exactly von Mises,
            %   so the sampling is exact rather than approximate.
            %
            %   Size is drawn from the set's size distribution conditioned on
            %   being at least the trace length (a chord cannot exceed the
            %   diameter). The centre then follows: offset sqrt(r^2-(L/2)^2)
            %   from the trace midpoint, perpendicular to the trace within the
            %   fracture plane.
            P = {}; sid = []; rep = struct('n',0,'grown',0,'coplanar',0,'stray',0);
            if isempty(T), return, end
            q = app.FacetSpin.Value;
            n = sec.n; e1 = sec.e1; e2 = sec.e2; p0 = sec.p0;
            P = cell(size(T,1),1); sid = zeros(size(T,1),1);
            k = 0; grown = 0; coplanar = 0;
            for i = 1:size(T,1)
                P1 = p0 + T(i,1)*e1 + T(i,2)*e2;
                P2 = p0 + T(i,3)*e1 + T(i,4)*e2;
                L  = norm(P2-P1);
                if L < eps, continue, end
                t  = (P2-P1)/L;  M = 0.5*(P1+P2);
                si = app.setForTrace(i, t, D, n);
                % --- the free rotation, sampled from the set's pole density --
                w0 = cross(t, n); w0 = w0/norm(w0);
                mu = app.planeNormal(D(si,2), D(si,4));   % the set's mean pole
                kp = app.setKappa(D(si,3), D(si,5), D(si,:));
                cA = dot(n, mu); cB = dot(w0, mu);
                phi0 = atan2(cB, cA);
                R = hypot(cA, cB);                        % concentration factor
                % A draw can still land on the section plane itself, which
                % carries no trace. That is a measure-zero event the sampler
                % can hit when the set's mean pole is near the section normal,
                % so try again a few times before giving the trace up - one
                % unlucky draw is not a reason to lose a mapped fracture.
                nf = [];
                for attempt = 1:12
                    phi = circ_vmrnd(phi0, max(kp*R, 1e-6), 1);
                    v = cos(phi)*n + sin(phi)*w0;
                    if abs(dot(v, t)) > 1e-9              % keep it perp to t
                        v = v - dot(v,t)*t;
                    end
                    if norm(v) < 1e-9, continue, end
                    v = v/norm(v);
                    if abs(dot(v, n)) < 1-1e-6, nf = v; break, end
                end
                if isempty(nf)
                    % every draw came out parallel to the section, which
                    % cannot cut it and so cannot carry a trace
                    coplanar = coplanar + 1;
                    continue
                end
                w = cross(nf, t); w = w/norm(w);
                % --- size, conditioned on covering the trace -----------------
                lo = max(D(si,6), L); hi = D(si,8);
                if hi < lo, hi = lo*1.05; grown = grown + 1; end
                sz = app.drawSizes(1, D(si,:), lo, hi);
                if ~isfinite(sz) || sz < lo
                    % The truncated-exponential sampler saturates when the
                    % trace is far longer than the set's mean size: expcdf(lo)
                    % rounds to exactly 1 and expinv(1) is Inf, which used to
                    % produce NaN fractures that Clip then dropped in silence.
                    % Fall back to the smallest size that covers the trace.
                    sz = lo;
                end
                r  = 0.5*sz;
                if r < L/2, r = L/2 + eps(L); end
                d  = sqrt(max(r^2 - (L/2)^2, 0));
                C  = M + d*w * (2*(rand>0.5)-1);          % either side
                th = linspace(0, 2*pi, q+1)'; th(end) = [];
                % not 'q': that is the facet count, and shadowing it made
                % linspace(0,2*pi,q+1) fail on the second trace
                %
                % The maths above places the fracture so the CIRCLE of radius
                % r cuts the section exactly along P1..P2. The fracture drawn
                % is a q-gon inscribed in that circle, and its edges fall
                % inside it - so unless an endpoint happens to land on a
                % vertex, the section cut the chord short by up to one facet
                % sagitta, r(1-cos(pi/q)): 0.010 at r = 1.2, q = 24, which is
                % exactly the shortfall measured against the example maps.
                % Both endpoints are on the circle by construction, so make
                % them vertices and the reproduced trace is exact.
                a1 = atan2(dot(P1-C, w), dot(P1-C, t));
                a2 = atan2(dot(P2-C, w), dot(P2-C, t));
                th = unique([mod(th,2*pi); mod(a1,2*pi); mod(a2,2*pi)]);
                ply = C + r*(cos(th)*t + sin(th)*w);
                if ~all(isfinite(ply(:))), continue, end
                k = k + 1;
                P{k}   = ply;
                sid(k) = si;
                dev(k) = acosd(min(1, abs(dot(nf, mu)))); %#ok<AGROW>
            end
            P = P(1:k); sid = sid(1:k);
            rep.n = k; rep.grown = grown; rep.coplanar = coplanar;
            % How far the conditioned fractures ended up from the mean pole of
            % the set they were assigned to. A trace fixes the plane it lies
            % in, so some deviation is expected and healthy; a large median
            % means no set in the table can really produce this map, and the
            % traces are being honoured by fractures that do not belong to any
            % set you entered. Worth saying out loud rather than burying.
            if k > 0, rep.stray = median(dev(1:k)); end
        end

        function si = setForTrace(app, i, t, D, n)
            %SETFORTRACE  Which joint set a mapped trace belongs to.
            %   Auto mode compares the trace direction the set would MAKE on
            %   this face against the one observed.
            %
            %   It used to score |dot(pole, t)|, smaller being better, on the
            %   reasoning that the trace lies in the fracture plane. True, but
            %   it has a blind spot exactly where it hurts: a set parallel to
            %   the face has its pole along the section normal, and every
            %   trace direction is perpendicular to that, so such a set scored
            %   a perfect 0 for every trace and was picked every time - while
            %   being the one set that cannot cut the face at all. Every trace
            %   it took was then thrown out as coplanar, and conditioning
            %   honoured nothing.
            si = 1;
            if ~isempty(app.CondSetDD) && app.CondSetDD.Value > 0
                si = min(app.CondSetDD.Value, size(D,1)); return
            end
            if ~isempty(app.TraceSid) && i <= numel(app.TraceSid) && ...
                    app.TraceSid(i) >= 1 && app.TraceSid(i) <= size(D,1)
                si = round(app.TraceSid(i)); return
            end
            if nargin < 5 || isempty(n), return, end
            best = inf;
            for j = 1:size(D,1)
                mu = app.planeNormal(D(j,2), D(j,4));
                u  = cross(n, mu);                  % the trace this set makes
                if norm(u) < 1e-6, continue, end    % parallel: it makes none
                u = u / norm(u);
                a = 1 - abs(dot(t, u));             % 0 = same line
                if a < best, best = a; si = j; end
            end
        end

        function kp = setKappa(app, ddip, dddir, row)
            %SETKAPPA  A single Fisher concentration for a set's pole.
            %   Under the Fisher model that is the table's own kappa. Under
            %   ADFNE's: negative dDip/dDipDir already are kappa, a uniform
            %   spread of +/- x degrees is matched by kappa ~ 1/rad(x)^2, a
            %   fixed orientation is the kappa -> large limit.
            if strcmp(app.orientModel(), 'fisher'), kp = max(ddip, 1e-6); return, end
            if any(strcmp(app.orientModel(), {'bvn','kent','bingham'}))
                dp = 45; if nargin >= 4, dp = row(2); end
                kp = app.scatterToFisher(app.orientModel(), [0 dp ddip 0 dddir 0 0 0 0]);
                return
            end
            if strcmp(app.orientModel(), 'boot')
                kp = 30;
                if nargin >= 4
                    M = app.mappedPolesForSet(row);
                    if ~isempty(M)
                        m = app.meanAxis(num2cell(M, 2)'); M(M*m' < 0, :) = -M(M*m' < 0, :);
                        kp = app.fisherKappa(M);
                    end
                end
                return
            end
            v = [ddip dddir];
            k = zeros(1,2);
            for i = 1:2
                if v(i) < 0,      k(i) = -v(i);
                elseif v(i) == 0, k(i) = 1e6;
                else,             k(i) = 1/deg2rad(v(i))^2;
                end
            end
            % the table's dDip kappa is in DFN's compressed convention and
            % acts about sixteen times more concentrated than it reads
            if v(1) < 0, k(1) = app.dipKappaFromTable(k(1)); end
            kp = min(k);
        end

        function keep = crossesFace(app, P, sec)
            %CROSSESFACE  Which fractures cut the mapped face inside its window.
            keep = false(numel(P),1);
            if isempty(sec) || ~isfield(sec,'faceUV') || isempty(sec.faceUV)
                return
            end
            for i = 1:numel(P)
                qy = P{i};
                sd = (qy - sec.p0) * sec.n(:);
                if all(sd > 0) || all(sd < 0), continue, end
                uv = app.toPlaneUV(sec, qy);
                if any(isPointInPolygon(uv, sec.faceUV)), keep(i) = true; end
            end
        end

        function n = planeNormal(~, dip, ddir)
            %PLANENORMAL  Unit normal for a plane of given dip / dip direction,
            %   in ADFNE's own convention: a plane built by rotating the base
            %   x = 0 polygon through Ry(-90+dip) then Rz(ddir) has this normal,
            %   and Orientation() recovers dip and dip direction from it.
            n = [sind(dip)*cosd(ddir), sind(dip)*sind(ddir), cosd(dip)];
            n = n / norm(n);
        end

        function sec = sectionGeometry(app, rgn)
            %SECTIONGEOMETRY  Plane, in-plane axes and the face outline.
            sec = struct();
            sec.dip  = app.SecDipF.Value;
            sec.ddir = app.SecDirF.Value;
            sec.off  = app.SecOffF.Value;
            n = app.planeNormal(sec.dip, sec.ddir);
            c = [mean(rgn(1:2)), mean(rgn(3:4)), mean(rgn(5:6))];
            sec.n  = n;
            sec.p0 = c + sec.off * n;                   % offset along the normal
            % in-plane axes: e1 horizontal where possible (the strike direction)
            e1 = cross([0 0 1], n);
            if norm(e1) < 1e-9, e1 = [1 0 0]; end       % plane is horizontal
            e1 = e1 / norm(e1);
            e2 = cross(n, e1);  e2 = e2 / norm(e2);
            sec.e1 = e1; sec.e2 = e2;
            % the face: a large square in the plane, clipped to the domain
            d = norm([rgn(2)-rgn(1), rgn(4)-rgn(3), rgn(6)-rgn(5)]);
            q = sec.p0 + d*[ e1+e2; e1-e2; -e1-e2; -e1+e2 ];
            f = Clip({q}, app.bbx15(rgn, 3));
            if isempty(f)
                sec.face = zeros(0,3); sec.faceUV = zeros(0,2);
                sec.box = [0 1 0 1];
                return
            end
            sec.face   = f{1};
            sec.faceUV = app.toPlaneUV(sec, sec.face);
            sec.box    = [min(sec.faceUV(:,1)) max(sec.faceUV(:,1)) ...
                          min(sec.faceUV(:,2)) max(sec.faceUV(:,2))];
        end

        function uv = toPlaneUV(~, sec, pts)
            %TOPLANEUV  3D points -> in-plane coordinates of the section.
            d = pts - sec.p0;
            uv = [d * sec.e1(:), d * sec.e2(:)];
        end

        function computeSection(app)
            %COMPUTESECTION  Traces where the 3D fractures meet the section
            %   plane, projected into the plane's own 2D coordinates so every
            %   2D analysis in the Analysis tab works on them unchanged.
            m = app.Model;
            app.Model.sec = struct('lines',zeros(0,4),'setid',[], ...
                'traces3d',zeros(0,6),'box',[0 1 0 1]);
            if isempty(m.fnm) || ~iscell(m.fnm), return, end
            sec = app.sectionGeometry(m.rgn);
            [L3, sid] = app.tracesOnPlane(m.fnm, sec, m.setid);
            uv1 = app.toPlaneUV(sec, L3(:,1:3));
            uv2 = app.toPlaneUV(sec, L3(:,4:6));
            sec.lines    = [uv1, uv2];
            sec.setid    = sid;
            sec.traces3d = L3;
            app.Model.sec = sec;
        end

        function [L3, sid, src] = tracesOnPlane(~, P, sec, setid)
            %TRACESONPLANE  Segments where fractures meet the section plane.
            %   Shared by the 2D view, the fitter and the clip aid, so what the
            %   fit sees and what the viewport draws are the same thing.
            %
            %   src is the index of the fracture each trace came from. Asking
            %   this function rather than repeating the geometry is what lets
            %   "only fractures with a trace" mean exactly the traces on
            %   screen, with no second test to drift out of step.
            if nargin < 4, setid = []; end
            n = sec.n; p0 = sec.p0;
            L3 = zeros(numel(P), 6); sid = zeros(numel(P), 1);
            src = zeros(numel(P), 1); k = 0;
            for i = 1:numel(P)
                q = P{i};
                if size(q,1) < 3, continue, end
                sd = (q - p0) * n(:);
                if all(sd > 0) || all(sd < 0), continue, end   % no crossing
                e1i = (1:size(q,1))';
                e2i = [e1i(2:end); e1i(1)];
                a = sd(e1i); b = sd(e2i);
                cr = (a .* b) < 0;                      % edge straddles plane
                on = abs(a) < 1e-12;                    % vertex on the plane
                pts = zeros(0,3);
                if any(cr)
                    t = a(cr) ./ (a(cr) - b(cr));
                    pts = [pts; q(e1i(cr),:) + t .* (q(e2i(cr),:) - q(e1i(cr),:))]; %#ok<AGROW>
                end
                if any(on), pts = [pts; q(on,:)]; end   %#ok<AGROW>
                if size(pts,1) < 2, continue, end
                if size(pts,1) > 2                      % keep the extremes
                    dd = sqrt(sum((permute(pts,[1 3 2]) - permute(pts,[3 1 2])).^2, 3));
                    [~, ix] = max(dd(:));
                    [r1, r2] = ind2sub(size(dd), ix);
                    pts = pts([r1 r2], :);
                end
                k = k + 1;
                L3(k,:) = [pts(1,:), pts(2,:)];
                src(k) = i;
                if ~isempty(setid) && i <= numel(setid), sid(k) = setid(i); end
            end
            L3 = L3(1:k,:); sid = sid(1:k); src = src(1:k);
        end

        function [fnm, box2, sid] = viewData(app)
            %VIEWDATA  What the current view works on: the 3D fractures, or the
            %   traces they cut on the section plane.
            m = app.Model;
            % Read setid defensively rather than by name: a session saved
            % before it existed is loaded straight into app.Model, so the
            % field can be missing on a model that is otherwise complete.
            sid = [];
            if app.is2DView() && isfield(m,'sec') && ~isempty(m.sec)
                fnm  = m.sec.lines;
                box2 = m.sec.box;
                if isfield(m.sec,'setid'), sid = m.sec.setid; end
            else
                fnm  = m.fnm;
                % liveRgn, not m.rgn: with no model built this is what draws
                % the region box, and Model.rgn is still the default unit box
                % however large a domain has been typed.
                rg   = app.liveRgn();
                box2 = [rg(1) rg(2) rg(3) rg(4)];
                if isfield(m,'setid'), sid = m.setid; end
            end
        end

        function rgn = liveRgn(app)
            %LIVERGN  The domain a preview should be drawn against.
            %   Model.rgn is what GENERATE actually built, and every analysis
            %   must keep using it. But Section plane and Trace map are meant
            %   to work BEFORE anything is generated -- that is when checking
            %   the geometry matters most -- and until then Model.rgn is still
            %   the default unit box while the fields say something else. So a
            %   map imported for a 6 x 5 face was drawn against a 1 x 1 face
            %   and reported entirely off it.
            rgn = app.Model.rgn;
            if isempty(app.Model.fnm) && ~isempty(app.RgnFields) && ...
                    all(isvalid(app.RgnFields))
                rgn = [app.RgnFields.Value];
            end
        end

        function tf = is2DView(app)
            tf = ~isempty(app.ModeDD) && strcmp(app.ModeDD.Value, '2D');
        end

        function onTogglePlane(app)
            %ONTOGGLEPLANE  Show the section-plane preview, or go back.
            %   Ticking remembers whatever was being plotted so unticking can
            %   restore it; it used to be a button, which could only ever
            %   switch the plot type one way.
            if app.SecShowCB.Value
                if ~strcmp(app.PlotDD.Value,'Section plane')
                    app.PrevPlot = app.PlotDD.Value;
                end
                if any(strcmp('Section plane', app.PlotDD.Items))
                    app.PlotDD.Value = 'Section plane';
                    % Open looking at the face itself, obliquely. This used to
                    % be a fixed isometric (-35, 20), which framed the domain
                    % rather than the plane: on most orientations you met the
                    % section edge-on, as a line. Deriving the angles from the
                    % plane normal turns it to you whatever its dip and dip
                    % direction, while the swing off dead-on keeps the block
                    % reading as a solid. Drag to rotate from there.
                    [az, el] = app.faceSectionAngles( ...
                        app.sectionGeometry([app.RgnFields.Value]));
                    app.AzSld.Value = az; app.ElSld.Value = el;
                else
                    % unreachable through the UI - the checkbox is disabled in
                    % the 3D view - but harmless if reached programmatically
                    app.SecShowCB.Value = false; return
                end
            else
                back = app.PrevPlot;
                if isempty(back) || ~any(strcmp(back, app.PlotDD.Items))
                    back = app.PlotDD.Items{1};
                    if strcmp(back,'Section plane') && numel(app.PlotDD.Items) > 1
                        back = app.PlotDD.Items{2};
                    end
                end
                app.PlotDD.Value = back;
            end
            % switching view re-syncs the checkbox from the plot type, which
            % at that moment is not yet the one we are about to select
            app.syncPlaneCB();
            app.renderPlot();
        end

        function tidySectionAxes(app, sec)
            %TIDYSECTIONAXES  Drop an axis only when it collapses to a point.
            %   Looking straight down the plane normal, one coordinate axis is
            %   edge-on and its ticks are noise. From any other angle - ISO
            %   included - all three carry depth, so they stay.
            if isempty(sec) || ~isvalid(app.Ax), return, end
            for ax = 'XYZ', app.Ax.([ax 'Color']) = [0.13 0.13 0.13]; end
            % from View rather than campos: the camera properties have not
            % been flushed at this point and still hold the previous frame
            v = app.Ax.View;
            d = [sind(v(1))*cosd(v(2)), -cosd(v(1))*cosd(v(2)), sind(v(2))];
            [~, flat] = max(abs(sec.n));
            if abs(sec.n(flat)) > 0.999 && abs(dot(d, sec.n)) > 0.99
                switch flat
                    case 1, app.Ax.XColor = 'none';
                    case 2, app.Ax.YColor = 'none';
                    case 3, app.Ax.ZColor = 'none';
                end
            end
        end

        function syncPlaneCB(app)
            %SYNCPLANECB  Keep the checkbox honest when the plot type changes
            %   by any other route - the Plot list, or a change of view.
            if isempty(app.SecShowCB), return, end
            app.SecShowCB.Value = strcmp(app.PlotDD.Value,'Section plane');
            app.syncClipEnable();
        end

        function syncClipEnable(app)
            %SYNCCLIPENABLE  Clipping only means anything in the intersect view.
            if isempty(app.SecClipDD) || ~isvalid(app.SecClipDD), return, end
            ok = app.is2DView() && ~isempty(app.SecShowCB) && app.SecShowCB.Value;
            app.SecClipDD.Enable = matlab.lang.OnOffSwitchState(ok);
        end

        function [plys, sid] = clipToSection(app, plys, sid, sec)
            %CLIPTOSECTION  Drop the fractures that bury the section plane.
            %   Purely a viewing aid: nothing is cut in two, so the traces on
            %   the plane stay exactly what they were, and the model and every
            %   analysis are untouched.
            mode = 'no clipping';
            if ~isempty(app.SecClipDD), mode = app.SecClipDD.Value; end
            if strcmp(mode,'no clipping') || isempty(plys), return, end
            k = numel(plys);

            if strcmp(mode,'only fractures with a trace')
                % Exactly the fractures that produced the traces you are
                % looking at -- asked of tracesOnPlane rather than tested
                % again here, so the two can never disagree.
                %
                % This replaced a slab of 8% of the domain diagonal either
                % side of the plane, which was only ever an approximation of
                % this: the comment said it "keeps the fractures that actually
                % make the traces and little else", and "little else" was
                % doing real work. A wide fracture at a shallow angle makes a
                % trace with its centre well outside any slab, and a small one
                % just inside the slab need not touch the plane at all.
                % Note these fractures sit on BOTH sides of the plane, so this
                % is not a subset of either half.
                [~, ~, src] = app.tracesOnPlane(plys, sec);
                keep = false(k,1);
                keep(src) = true;
            else
                sd = zeros(k,1);
                for i = 1:k
                    q = plys{i};
                    if isempty(q), continue, end
                    sd(i) = (mean(q,1) - sec.p0) * sec.n(:);
                end
                % A fracture goes with whichever side its centre lies on.
                switch mode
                    case 'hide front block', keep = sd <= 0;
                    otherwise,               keep = sd >= 0;
                end
            end
            plys = plys(keep);
            if numel(sid) == k, sid = sid(keep); end
        end

        function onDomainChanged(app)
            %ONDOMAINCHANGED  Keep what is on screen honest about the domain.
            %   The domain is generative, so refreshStateBar is free to mark
            %   the model out of date -- that is the correct answer once one
            %   exists. Before then, the previews are all there is, and they
            %   are drawn from these fields.
            app.describeInherited();
            app.refreshStateBar();
            if isempty(app.Model.fnm) && ...
                    any(strcmp(app.PlotDD.Value,{'Section plane','Trace map','Mapped planes'}))
                app.renderPlot();
            end
        end

        function onSectionChanged(app)
            app.describeInherited();
            showing = any(strcmp(app.PlotDD.Value,{'Section plane','Trace map','Mapped planes'}));
            if isempty(app.Model.fnm)
                if showing, app.renderPlot(); end     % no model, just the plane
                return
            end
            % recompute the traces BEFORE redrawing: an earlier version
            % returned early to render the plane and left the trace count
            % frozen at whatever the previous offset produced
            app.computeSection();
            app.describeSection();
            if showing || app.is2DView(), app.renderPlot(); end
        end

        function describeSection(app)
            if ~isfield(app.Model,'sec') || isempty(app.Model.sec), return, end
            sc = app.Model.sec;
            if isfield(sc,'n')
                app.log(sprintf(['Section dip %g / dipdir %g, offset %g: ' ...
                    '%d traces on a %.3g x %.3g face.'], sc.dip, sc.ddir, ...
                    sc.off, size(sc.lines,1), sc.box(2)-sc.box(1), ...
                    sc.box(4)-sc.box(3)));
            end
        end

        function needSamples(~, pts, n, what)
            %NEEDSAMPLES  The geostatistics need points to work from.
            %   They used to say so only through whatever ADFNE hit first: on
            %   a section that cuts nothing, Kriging came back with "Inputs
            %   must be scalars" from inside linspace, which names neither the
            %   cause nor the cure.
            if size(pts,1) >= n, return, end
            error('ADFNE:TooFewSamples', ...
                ['%s needs at least %d fractures to work from, and this view ' ...
                 'has %d. In the 2D view the samples are the traces on the ' ...
                 'section plane, so move the plane to where it cuts the rock ' ...
                 'mass, or generate a denser network.'], what, n, size(pts,1));
        end

        function [pts, val] = geoSample(~, fnm)
            %GEOSAMPLE  Points and a value per fracture, for the geostatistics.
            %   Fracture centres carrying their own size. It is a stand-in for a
            %   measured property: replace val in the console with your own data
            %   at the same points and every geostatistical tool still applies.
            if iscell(fnm)
                pts = Center(fnm);
                val = Length(fnm);
                pts = pts(:,1:2);                  % krige on plan view
            else
                pts = [(fnm(:,1)+fnm(:,3))/2, (fnm(:,2)+fnm(:,4))/2];
                val = sqrt(sum((fnm(:,3:4)-fnm(:,1:2)).^2, 2));
            end
            val = val(:);
            ok = all(isfinite(pts),2) & isfinite(val);
            pts = pts(ok,:); val = val(ok);
        end

        function info = intensity3D(app, plys, rgn)
            %INTENSITY3D  P32, fracture area per unit rock volume - the measure
            %   used to calibrate a DFN against field mapping. ADFNE 1.5 has no
            %   equivalent, so it is computed here from the clipped polygons.
            info = struct();
            vol = (rgn(2)-rgn(1)) * (rgn(4)-rgn(3)) * (rgn(6)-rgn(5));
            if isempty(plys) || vol <= 0, return, end
            a = zeros(numel(plys),1);
            for i = 1:numel(plys)
                a(i) = abs(polygonArea3d(plys{i}));
            end
            info.area = a;
            info.area_total = sum(a);
            info.P32_clipped = sum(a) / vol;
            % P33: fracture volume per unit rock volume, at the one aperture
            % the Flow tab holds; and P10 along the section-plane normal
            ap = 0;
            if ~isempty(app.FlowApF) && isvalid(app.FlowApF), ap = app.FlowApF.Value; end
            info.aperture = ap;
            info.P33 = info.P32_clipped * ap;
            try
                sec = app.sectionGeometry(rgn);
                info.P10_normal = app.p10ForNetwork(plys, rgn, sec.n);
            catch
                info.P10_normal = NaN;
            end
        end

        function L = spreadLines2D(~, L, rgn2)
            % GenFNM2D always drops fracture centres in the unit square, whatever
            % region it is given (it only uses the region to clip). Re-map the
            % centres so they fill the requested domain; segment vectors, and so
            % the L min / L max lengths, are left untouched.
            if isempty(L), return; end
            cx = (L(:,1) + L(:,3)) / 2;
            cy = (L(:,2) + L(:,4)) / 2;
            dx = rgn2(1) + (rgn2(2) - rgn2(1)) * cx - cx;
            dy = rgn2(3) + (rgn2(4) - rgn2(3)) * cy - cy;
            L = L + [dx dy dx dy];
        end

        function P = spreadPolys3D(~, P, rgn3)
            % Same story as spreadLines2D for GenFNM3DE: centres are always drawn
            % in the unit cube, so translate each polygon into the real domain.
            % Only the centroid moves - the Size column keeps its meaning.
            lo = rgn3([1 3 5]);
            sc = rgn3([2 4 6]) - lo;
            for i = 1:numel(P)
                p = P{i};
                if isempty(p), continue; end
                c = mean(p, 1);
                u = min(max(c, 0), 1);      % centroid drifts a little off pt
                P{i} = p + (lo + sc .* u - c);
            end
        end

        function P = cleanPolys(~, P)
            keep = false(numel(P),1);
            for i = 1:numel(P)
                p = P{i};
                keep(i) = ~isempty(p) && size(p,1) >= 3 && all(isfinite(p(:)));
            end
            P = P(keep);
        end
    end

    %% ----------------------------------------------------------- Analysis tab
    methods (Access = public, Hidden = true)

        function refreshAnalyses(app)
            if app.is2DView()
                items = { ...
                 'Clusters | LinesToClusters2D', ...
                 'Intersections | LinesX2D', ...
                 'Backbone | Backbone2D', ...
                 'Isolated fractures | IsolatedLines2D', ...
                 'Density map | Density2D', ...
                 'Connectivity field | ConnectivityField2D', ...
                 'Generalised CF | GeneralisedConnectivityField2D', ...
                 'Connectivity index | ConnectivityIndex2D', ...
                 'Intensity P21 | P21G', ...
                 'Intensity P22 | P22G', ...
                 'Connectivity matrix | ConnectivityMatrix', ...
                 'Graph metrics | FNMToGraph', ...
                 'Trace length statistics | mapped trace lengths', ...
                 'Variogram | Variocloud + Variogram', ...
                 'Kriging map | Kriging', ...
                 'Upscale a result grid | Upscaling', ...
                 'Statistics | lengths & orientations'};
            else
                items = { ...
                 'Intersections + clusters | PolysX3D', ...
                 'Pipe model | FNMPipes3D', ...
                 'Traces on plane | SlicePoly3D / PolyXPlane3D', ...
                 'Intensity P10/P21/P32 | Intensity3D', ...
                 'Orientation | Orientation3D', ...
                 'Sizes | Size3D', ...
                 'Centroids | Centroids3D', ...
                 'Bounding box | BBox3D', ...
                 'Borehole sampling | FNMfromBorehole', ...
                 'Connectivity matrix | ConnectivityMatrix', ...
                 'Graph metrics | FNMToGraph', ...
                 'Variogram | Variocloud + Variogram', ...
                 'Kriging map | Kriging', ...
                 'Upscale a result grid | Upscaling', ...
                 'Statistics | sizes & orientations'};
            end
            app.AnaList.Items = items;
            app.AnaList.Value = {};
            app.fitAnaList();
            app.refreshAnalysisParams();
        end

        function refreshAnalysisParams(app)
            %REFRESHANALYSISPARAMS  Show only what the highlighted analyses read.
            %   The panel used to show borehole geometry and a slice axis
            %   whatever was selected, so it always looked as complicated as it
            %   could possibly get and gave no clue which numbers the next run
            %   would actually use.
            if isempty(app.AnaParamGrid) || ~isvalid(app.AnaParamGrid), return, end

            keys = strings(0);
            sel = string(app.AnaList.Value);
            if ~isempty(sel)
                keys = strtrim(extractBefore(sel + " | ", " | "));
            end
            % Every analysis that samples onto a grid reads Grid N. Kriging and
            % upscaling are offered in both views; the rest are 2D only.
            gridUsers = ["Density map","Connectivity field","Generalised CF", ...
                         "Connectivity index","Intensity P21","Intensity P22", ...
                         "Kriging map","Upscale a result grid"];
            want = [any(ismember(keys, gridUsers)), ...
                    any(keys == "Traces on plane"), ...
                    any(keys == "Borehole sampling")];
            rows = {app.AnaGridRow, app.AnaSliceRow, app.AnaBhRow};

            on = @(b) matlab.lang.OnOffSwitchState(b);
            for i = 1:3
                for h = rows{i}
                    if ~isempty(h) && isvalid(h), h.Visible = on(want(i)); end
                end
            end
            app.AnaParamHint.Visible = on(~any(want));

            % Which grid rows each group occupies: Grid N shares row 1 with the
            % hint, the slice axis has row 2, and the borehole needs two rows
            % because its XY and Z run onto a second line.
            rh = app.AnaParamGrid.RowHeight;
            rh{1} = 24 * (want(1) || ~any(want));
            rh{2} = 24 * want(2);
            rh{3} = 24 * want(3);
            rh{4} = 24 * want(3);
            app.AnaParamGrid.RowHeight = rh;

            % Size the panel to what it is showing, so hidden rows give their
            % height back to the results table rather than leaving a gap.
            shown = sum([rh{:}] > 0);
            gh = app.AnaGrid.RowHeight;
            gh{3} = app.panelH(max(1, shown));
            app.AnaGrid.RowHeight = gh;
        end

        function fitAnaList(app)
            %FITANALIST  Size the list to its contents.
            %   The tab already scrolls, so a listbox with its own scrollbar
            %   put a second one right beside the first - and the inner one is
            %   easy to miss. At 190 px it showed 10 of 15 entries and the
            %   geostatistics, which sit at the bottom, looked as though they
            %   were not in the app at all. Sizing the list to fit leaves one
            %   scrollbar on the tab and nothing hidden inside it.
            if isempty(app.AnaList) || ~isvalid(app.AnaList), return, end
            g = app.AnaList.Parent;
            if ~isa(g,'matlab.ui.container.GridLayout'), return, end
            rh = g.RowHeight;
            r  = app.AnaList.Layout.Row;
            if r < 1 || r > numel(rh), return, end
            % 18 px a row, plus room for the horizontal scrollbar the longest
            % entry brings with it
            rh{r} = numel(app.AnaList.Items)*18 + 26;
            g.RowHeight = rh;
        end

        function onClearResults(app)
            app.Model.results = struct();
            app.ResTable.Data = cell(0,2);
            app.refreshPlotTypes();
            app.log('Results cleared.');
        end

        function onRunAnalysis(app)
            app.refreshStateBar();
            if isempty(app.Model.fnm)
                uialert(app.Fig,'Generate a network first.','No model'); return
            end
            sel = app.AnaList.Value;
            if ischar(sel), sel = {sel}; end
            if isempty(sel)
                uialert(app.Fig,'Select at least one analysis.','Nothing selected'); return
            end
            cl = app.busy('Running the selected analyses…', true, 'analyses'); %#ok<NASGU>
            for i = 1:numel(sel)
                app.setStatus(sel{i});
                try
                    t0 = tic;
                    app.runOneAnalysis(sel{i});
                    app.log(sprintf('%s  (%.2f s)', sel{i}, toc(t0)),'ok');
                catch ME
                    app.log(sprintf('%s FAILED: %s', sel{i}, ME.message),'error');
                end
            end
            app.refreshResultsTable();
            app.refreshPlotTypes();
            app.syncVars();
        end

        function G = gridFrame(~, L, box, gn)
            %GRIDFRAME  Put section traces into the unit square that ADFNE's
            %   grid functions assume, and give back what is needed to read
            %   the answer in real coordinates again.
            %
            %   Density2D, P21G, P22G, ConnectivityField2D, Generalised-
            %   ConnectivityField2D and ConnectivityIndex2D all hard-code
            %   their support grid as w = 1/gn over [0,1]^2. A section's own
            %   (u,v) box is nothing like that - a 6 x 5 face runs -3..3 by
            %   -2.5..2.5 - so each of them was sampling one small corner of
            %   the face and reporting it as the whole thing.
            %
            %   The scaling is isotropic, so a length divides back out by s
            %   alone and an area by s^2. The face lands in the lower-left of
            %   the unit square; cells past its edge are masked rather than
            %   counted as empty rock, which would drag every mean down.
            bw = box(2) - box(1); bh = box(4) - box(3);
            G.s = 1 / max([bw, bh, eps]);
            G.box = box;
            G.lines = [(L(:,1)-box(1))*G.s, (L(:,2)-box(3))*G.s, ...
                       (L(:,3)-box(1))*G.s, (L(:,4)-box(3))*G.s];
            w = 1/gn;
            % centres of the grid cells, back in real (u,v) units
            cu = box(1) + ((1:gn)-0.5)*w/G.s;
            cv = box(3) + ((1:gn)-0.5)*w/G.s;
            G.nx = max(1, sum(cu <= box(2)));
            G.ny = max(1, sum(cv <= box(4)));
            G.x = [cu(1) cu(G.nx)];  G.y = [cv(1) cv(G.ny)];
            G.gn = gn;
            G.cellArea = (w/G.s)^2;                        % real area per cell
        end

        function M = cropGrid(~, M, G)
            %CROPGRID  Keep only the cells that lie on the face.
            %   A non-square face occupies a corner of the unit square the
            %   grid functions work over. Cropping rather than masking keeps
            %   every downstream user - contours, upscaling, the statistics -
            %   free of a NaN margin it would have to know about.
            M = M(1:min(G.ny,size(M,1)), 1:min(G.nx,size(M,2)));
        end

        function runOneAnalysis(app, name)
            m   = app.Model;
            fnm = app.viewData();       % 3D fractures, or the section's traces
            gn  = app.GridSpin.Value;
            key = extractBefore(string(name),' | ');
            R   = app.Model.results;

            switch char(key)
                case 'Trace length statistics'
                    % what you actually measure when mapping a face
                    tl = sqrt(sum((fnm(:,3:4)-fnm(:,1:2)).^2, 2));
                    R.traceLengths = tl;
                    R.traceLmin = min(tl); R.traceLmean = mean(tl);
                    R.traceLmax = max(tl); R.traceLstd = std(tl);
                    R.nTraces = numel(tl);
                case 'Variogram'
                    % spatial correlation of fracture size (3D) or trace
                    % length (2D) across the model - swap in a measured
                    % property from the console if you have one
                    [pts, val] = app.geoSample(fnm);
                    app.needSamples(pts, 3, 'A variogram');
                    [d, gm, v] = Variocloud(pts, val, [], false);
                    [dd, gg] = Variogram(d, gm, 3, v, false);
                    R.varioDist = dd(:); R.varioGamma = gg(:);
                    R.varioRange = max(dd(:));
                case 'Kriging map'
                    [pts, val] = app.geoSample(fnm);
                    app.needSamples(pts, 3, 'Kriging');
                    [d, ~, ~] = Variocloud(pts, val, [], false);
                    mdl = {'name','sph','nugget',0,'sill',var(val), ...
                           'range',0.35*max(d)};
                    [krg, err] = Kriging(pts, val, d, mdl, [gn gn], false);
                    R.kriging = krg; R.krigingError = err;
                    R.krigingModel = mdl;
                case 'Upscale a result grid'
                    % coarsens whichever grid result is available
                    % three of these four are produced by 2D analyses, so
                    % this was offered in the one view where they cannot exist
                    src = ''; M = [];
                    for f = {'P21','density','CF','kriging'}
                        if isfield(R,f{1}) && ~isempty(R.(f{1})) && ...
                                min(size(R.(f{1}))) >= 2
                            M = R.(f{1}); src = f{1}; break
                        end
                    end

                    if isempty(M)
                        error('ADFNE:NoGrid', ...
                            ['Nothing to upscale yet. Run a grid analysis first ' ...
                             '(density map, P21, connectivity field or kriging).']);
                    end
                    n = 2^floor(log2(min(size(M))));
                    M = M(1:n, 1:n);                       % Upscaling needs 2^k
                    R.upscaled = Upscaling(M, 'geometric', 2);
                    R.upscaledFrom = src;
                case 'Clusters'
                    R.La = LinesToClusters2D(fnm);
                    app.Model.La = R.La;
                    [R.nClusters, R.largestCluster, R.nIsolated] = ...
                        app.clusterStats(R.La);
                    app.log(app.clusterSummary(R.La));
                case 'Intersections'
                    [xts, ids, La] = LinesX2D(fnm);
                    R.xts = xts; R.ids = ids; R.La = La; app.Model.La = La;
                    R.nIntersections = numel(ids);
                    [R.nClusters, R.largestCluster, R.nIsolated] = ...
                        app.clusterStats(La);
                case 'Backbone'
                    B = Backbone2D(fnm, true);
                    if ~isempty(B), B(all(B==0,2),:) = []; end
                    R.backbone = B;
                    R.backboneSegments = size(B,1);
                case 'Isolated fractures'
                    b = IsolatedLines2D(fnm, 1e-9);
                    R.isolated = b; R.nIsolated = sum(b);
                case 'Density map'
                    G = app.gridFrame(fnm, m.sec.box, gn);
                    dn = app.cropGrid(Density2D(G.lines, gn, gn), G);
                    R.density = dn; R.densityX = G.x; R.densityY = G.y;
                    R.densityMean = mean(dn(:)); R.densityMax = max(dn(:));
                case 'Connectivity field'
                    if isempty(app.Model.La), app.Model.La = LinesToClusters2D(fnm); end
                    G = app.gridFrame(fnm, m.sec.box, gn);
                    CF = app.cropGrid(ConnectivityField2D(G.lines, app.Model.La, gn, gn), G);
                    R.CF = CF; R.CFX = G.x; R.CFY = G.y;
                    R.CFmean = mean(CF(:)); R.CFmax = max(CF(:));
                case 'Generalised CF'
                    if isempty(app.Model.La), app.Model.La = LinesToClusters2D(fnm); end
                    % rm/rn are the target cells the field is computed FOR.
                    % Doing every cell costs gn^4 support intersections - 160k
                    % at gn = 20 - so the target set is capped and coarsened,
                    % and the log says what was actually used.
                    G = app.gridFrame(fnm, m.sec.box, gn);
                    gcap = min(G.nx, 12);
                    rm = unique(round(linspace(1, G.nx, gcap)));
                    rn = unique(round(linspace(1, G.ny, min(G.ny, 12))));
                    gcf = app.cropGrid(GeneralisedConnectivityField2D(G.lines, ...
                        app.Model.La, gn, gn, rm, rn), G);
                    app.log(sprintf(['Generalised CF: %dx%d grid over the face, ' ...
                        'field taken over %d x %d target cells.'], ...
                        G.nx, G.ny, numel(rm), numel(rn)));
                    R.GCF = gcf; R.GCFX = G.x; R.GCFY = G.y;
                case 'Connectivity index'
                    if isempty(app.Model.La), app.Model.La = LinesToClusters2D(fnm); end
                    % cm/cn is the single cell the index is measured from;
                    % the centre of the domain is the sensible default
                    G = app.gridFrame(fnm, m.sec.box, gn);
                    % the centre of the FACE, not of the unit square the face
                    % sits in a corner of
                    cm = max(1, round(G.ny/2)); cn = max(1, round(G.nx/2));
                    CI = app.cropGrid(ConnectivityIndex2D(G.lines, app.Model.La, ...
                        gn, gn, cm, cn), G);
                    R.ciCell = [cm cn];
                    R.CI = CI; R.CIX = G.x; R.CIY = G.y; R.CImean = mean(CI(:));
                case 'Intensity P21'
                    % Two faults here. P21G returns the mean first and the
                    % grid second, so taking the first as the map drew a 1x1
                    % image. And its grid is unusable anyway: it counts with
                    % size(ClipLines2D(...),1), and ClipLines2D returns one
                    % row per INPUT line - zeroed when the line misses the
                    % cell - so every cell reports the whole network. P22G
                    % filters those zero rows; P21G does not.
                    % Density2D counts the same quantity correctly, via
                    % SupXNLines2D, so the count comes from there.
                    G = app.gridFrame(fnm, m.sec.box, gn);
                    ns = app.cropGrid(Density2D(G.lines, gn, gn), G);
                    p21 = ns / G.cellArea;                 % traces per real area
                    R.P21 = p21; R.P21X = G.x; R.P21Y = G.y;
                    R.P21mean = mean(p21(:));
                case 'Intensity P22'
                    G = app.gridFrame(fnm, m.sec.box, gn);
                    [~, Ls] = P22G(G.lines, gn, gn);
                    % Ls are lengths in the normalised frame: divide by s once
                    % for the length, then by the real cell area
                    p22 = app.cropGrid((Ls / G.s) / G.cellArea, G);
                    R.P22 = p22; R.P22X = G.x; R.P22Y = G.y;
                    R.P22mean = mean(p22(:));
                case 'Connectivity matrix'
                    n = app.countFractures();
                    if iscell(fnm), [~, ids, ~] = PolysX3D(fnm); else, [~, ids, ~] = LinesX2D(fnm); end
                    R.cm = ConnectivityMatrix(ids, n, true, true);
                    R.meanDegree = mean(sum(R.cm,2));
                case 'Graph metrics'
                    n = app.countFractures();
                    if iscell(fnm), [~, ids, ~] = PolysX3D(fnm); else, [~, ids, ~] = LinesX2D(fnm); end
                    cm = ConnectivityMatrix(ids, n, true, true);
                    G = graph(logical(cm), 'omitselfloops');
                    R.graph = G;
                    R.graphNodes = numnodes(G); R.graphEdges = numedges(G);
                    comp = conncomp(G);
                    R.graphComponents = max(comp);
                    R.graphLargestComp = max(histcounts(comp, 0.5:1:max(comp)+0.5));
                case 'Intersections + clusters'
                    [xts, ids, La] = PolysX3D(fnm);
                    R.xts = xts; R.ids = ids; R.La = La; app.Model.La = La;
                    R.nIntersections = numel(ids);
                    [R.nClusters, R.largestCluster, R.nIsolated] = ...
                        app.clusterStats(La);
                    app.log(app.clusterSummary(La));
                case 'Pipe model'
                    [pip, cas, cts, xts, ids, La] = FNMPipes3D(fnm);
                    R.pipes = pip; R.pipeCluster = cas; R.centroids = cts;
                    R.xtsMid = xts; R.pairIds = ids; R.La = La;
                    app.Model.La = La;
                    R.nPipes = size(pip,1); R.nIntersections = size(ids,1);
                case 'Traces on plane'
                    v = app.PlaneVal.Value;
                    switch app.PlaneDD.Value
                        case 'z', o = [0 0 v]; nrm = [0 0 1];
                        case 'y', o = [0 v 0]; nrm = [0 1 0];
                        otherwise, o = [v 0 0]; nrm = [1 0 0];
                    end
                    pln = createPlane(o, nrm);
                    T = {};
                    for i = 1:numel(fnm)
                        e = [fnm{i}, circshift(fnm{i},[-1 0])];
                        p = intersectEdgePlane(e, pln);
                        p = p(all(isfinite(p),2),:);
                        if size(p,1) >= 2, T{end+1} = p([1 end],:); end %#ok<AGROW>
                    end
                    R.traces = T; R.nTraces = numel(T);
                case 'Intensity P10/P21/P32'
                    [P10, P21] = Intensity3D(fnm);
                    vol = (m.rgn(2)-m.rgn(1))*(m.rgn(4)-m.rgn(3))*(m.rgn(6)-m.rgn(5));
                    R.P10 = P10; R.P21 = P21;
                    R.P32 = sum(polygonArea3d(fnm)) / vol;
                case 'Orientation'
                    [ds, dds] = app.orient(fnm);
                    R.dip = ds; R.dipdir = dds;
                    R.dipMean = rad2deg(mean(ds)); R.dipdirMean = rad2deg(mean(dds));
                case 'Sizes'
                    R.sizes = Size3D(fnm);
                    R.sizeMean = mean(R.sizes); R.sizeMax = max(R.sizes);
                case 'Centroids'
                    R.centroids = Centroids3D(fnm);
                case 'Bounding box'
                    [mn, mx] = BBox3D(fnm);
                    R.bboxMin = mn; R.bboxMax = mx;
                case 'Borehole sampling'
                    p1 = [app.BhX1.Value app.BhY1.Value app.BhZ1.Value];
                    p2 = [app.BhX1.Value app.BhY1.Value app.BhZ2.Value];
                    [bhl, wts] = FNMfromBorehole(fnm, p1, p2, 1, app.BhR.Value, 12, 0);
                    R.borehole = bhl; R.boreholeHits = numel(wts);
                case 'Statistics'
                    if iscell(fnm)
                        sz = Size3D(fnm); [ds, dds] = app.orient(fnm);
                        R.sizes = sz; R.dip = ds; R.dipdir = dds;
                        R.sizeMean = mean(sz); R.sizeStd = std(sz);
                        R.dipMean = rad2deg(mean(ds));
                    else
                        dx = fnm(:,3)-fnm(:,1); dy = fnm(:,4)-fnm(:,2);
                        R.lengths = hypot(dx,dy);
                        R.angles  = mod(atan2(dy,dx), pi);
                        R.lengthMean = mean(R.lengths); R.lengthStd = std(R.lengths);
                        R.lengthTotal = sum(R.lengths);
                        R.P21total = sum(R.lengths) / ...
                            ((m.rgn(2)-m.rgn(1))*(m.rgn(4)-m.rgn(3)));
                    end
                otherwise
                    error('Unhandled analysis: %s', name);
            end
            app.Model.results = R;
        end

        function refreshResultsTable(app)
            R = app.Model.results;
            f = fieldnames(R);
            rows = cell(0,2);
            for i = 1:numel(f)
                v = R.(f{i});
                if isnumeric(v) && isscalar(v)
                    rows(end+1,:) = {f{i}, char(sprintf('%.6g', double(v)))}; %#ok<AGROW>
                elseif isnumeric(v) && numel(v) <= 6 && isvector(v)
                    rows(end+1,:) = {f{i}, char(mat2str(round(double(v),4)))}; %#ok<AGROW>
                else
                    rows(end+1,:) = {f{i}, char(sprintf('<%s %s>', class(v), ...
                        mat2str(size(v))))}; %#ok<AGROW>
                end
            end
            app.ResTable.Data = rows;
        end
    end

    %% ------------------------------------------------------- plotting
    methods (Access = public, Hidden = true)

        function refreshPlotTypes(app)
            R = app.Model.results;
            has = @(f) isfield(R,f) && ~isempty(R.(f));
            if app.is2DView()
                it = {'Fracture network'};
                if ~isempty(app.Model.La),  it{end+1} = 'Clusters'; end
                if has('backbone'),         it{end+1} = 'Backbone'; end
                if has('isolated'),         it{end+1} = 'Isolated vs connected'; end
                if has('density'),          it = [it {'Density map','Density contours'}]; end
                if has('CF'),               it = [it {'Connectivity field','CF contours'}]; end
                if has('GCF'),              it{end+1} = 'Generalised CF'; end
                if has('CI'),               it{end+1} = 'Connectivity index'; end
                if has('P21'),              it{end+1} = 'P21 map'; end
                if has('P22'),              it{end+1} = 'P22 map'; end
                if has('xts'),              it{end+1} = 'Intersection points'; end
                if has('cm'),               it{end+1} = 'Connectivity matrix'; end
                if has('graph'),            it{end+1} = 'Topology graph'; end
                if has('flow'), it = [it {'Flow | solution','Flow | backbone', ...
                                          'Flow | pipes'}]; end
                if has('varioGamma'), it{end+1} = 'Variogram'; end
                if has('kriging'),    it{end+1} = 'Kriging map'; end
                if has('upscaled'),   it{end+1} = 'Upscaled grid'; end
                it = [it {'Rose diagram','Length histogram'}];
                % These describe the 3D rock mass, not the section, and they
                % read Model.fnm directly - so they work in either view. They
                % were listed under 3D only, which meant that while you were
                % looking at a face you could not check, on a stereonet, that
                % the joint sets you typed came out the way you meant. The
                % model is always 3D now; the view should not hide it.
                it = [it {'Stereonet (poles)','Dip histogram','Size histogram'}];
                if ~isempty(app.Model.La),  it{end+1} = 'Cluster size distribution'; end
            else
                it = {'Fracture network'};
                if ~isempty(app.Model.La),  it{end+1} = 'Clusters'; end
                if ~isempty(app.Model.La),  it{end+1} = 'Largest cluster'; end
                if has('pipes'),            it{end+1} = 'Pipe model'; end
                if has('xts'),              it{end+1} = 'Intersection traces'; end
                if has('traces'),           it{end+1} = 'Traces on plane'; end
                if has('centroids'),        it{end+1} = 'Centroids'; end
                if has('cm'),               it{end+1} = 'Connectivity matrix'; end
                if has('graph'),            it{end+1} = 'Topology graph'; end
                if has('flow'), it = [it {'Flow | solution','Flow | backbone', ...
                                          'Flow | pipes'}]; end
                if has('varioGamma'), it{end+1} = 'Variogram'; end
                if has('kriging'),    it{end+1} = 'Kriging map'; end
                if has('upscaled'),   it{end+1} = 'Upscaled grid'; end
                % Rose belongs here too. It was offered in the 2D view
                % only, which is exactly the complaint the stereonet drew from
                % the other side: two views, each hiding one of the two
                % orientation plots. Both are now in both.
                it = [it {'Stereonet (poles)','Size histogram','Dip histogram', ...
                          'Rose diagram'}];
                if ~isempty(app.Model.La),  it{end+1} = 'Cluster size distribution'; end
            end
            % Only in the 2D view: that view IS the section, so this is the
            % picture of what it means. In the 3D view the plot list stays as
            % it was, so switching to 3D returns to the fracture network.
            if app.is2DView(), it = [{'Section plane','Trace map'}, it]; end
            % The 3D band is a picture of the rock mass, so it sits in the
            % 3D list, after the network, whenever a 3D source is selected.
            if ~app.is2DView() && app.is3DSource()
                it = [it(1), {'Mapped planes'}, it(2:end)];
            end
            if isempty(app.Model.fnm)
                % Both of these are drawn from the live fields rather than
                % from a model, and both are most wanted before there is one:
                % the section to check the geometry, the trace map to see what
                % a fit would read.
                it = {'Section plane','(generate a network first)'};
                if app.is2DView()
                    it = {'Section plane','Trace map','(generate a network first)'};
                elseif app.is3DSource()
                    it = {'Section plane','Mapped planes','(generate a network first)'};
                end
            end
            old = app.PlotDD.Value;
            % A trace map does not survive a rebuild. Every caller of this is an
            % event that means "the model or the view changed", and the preview
            % of a conditioning input is not what any of them should leave on
            % screen -- that is what made a re-picked "2D | section face" keep
            % showing the imported map.
            if any(strcmp(old,{'Trace map','Mapped planes'})), old = app.PrevPlotTM; end
            app.PlotDD.Items = it;
            if ~isempty(old) && any(strcmp(old, it))
                app.PlotDD.Value = old;
            else
                app.PlotDD.Value = it{1};
            end
            app.syncPlaneCB();
            app.syncTraceMapBtn();
        end

        function autoRender(app)
            app.syncPlaneCB();
            if ~isempty(app.AutoCB) && app.AutoCB.Value, app.renderPlot(); end
        end

        function onViewSlider(app)
            try
                if ~isempty(app.Ax) && isvalid(app.Ax) && isa(app.Ax,'matlab.ui.control.UIAxes')
                    view(app.Ax, [app.AzSld.Value app.ElSld.Value]);
                    % moving the camera changes whether an axis is edge-on, and
                    % this path does not re-render, so tidy up here too
                    if strcmp(app.PlotDD.Value,'Section plane')
                        app.tidySectionAxes(app.sectionGeometry([app.RgnFields.Value]));
                    end
                end
            catch, end
        end

        function setView(app, v)
            app.AzSld.Value = v(1); app.ElSld.Value = v(2);
            app.onViewSlider();
        end

        function renderPlot(app)
            kind = app.PlotDD.Value;
            % the section plane is worth seeing before anything is generated
            if isempty(app.Model.fnm) && ...
                    ~any(strcmp(kind,{'Section plane','Trace map','Mapped planes'})), return; end
            if startsWith(kind,'('), return; end
            app.Ax.Visible = 'on';
            % Whether this needs a dialog depends on how long THIS plot type
            % took last time, not on the fracture count - batching made render
            % cost flat in the count, so the count predicts nothing. An
            % ordinary network render is under a second and stays quiet; a
            % connectivity field or a flow solution on a big model is not, and
            % says so from the second time onwards.
            n = app.countFractures();
            cl = app.busy(sprintf('rendering %s  (%d fractures)…', kind, n), ...
                          'auto', ['render:' kind]); %#ok<NASGU>
            % A failed render must not take the app down - you would lose the
            % model. But it used to vanish into the log, which also meant the
            % regression suite called renderPlot, caught nothing, and passed
            % every plot whether or not it drew. Record it as well as log it.
            app.LastRenderError = '';
            try
                switch kind
                    case {'Rose diagram'},              app.plotRose();
                    case {'Length histogram'},          app.plotHist('length');
                    case {'Size histogram'},            app.plotHist('size');
                    case {'Dip histogram'},             app.plotHist('dip');
                    case {'Cluster size distribution'}, app.plotClusterSizes();
                    case {'Connectivity matrix'},       app.plotConnMatrix();
                    case {'Topology graph'},            app.plotGraph();
                    case {'Stereonet (poles)'},         app.plotStereonet();
                    otherwise,                          app.plotMain(kind);
                end
                app.setStatus(sprintf('%s  |  %d fractures', kind, app.countFractures()));
            catch ME
                app.LastRenderError = ME.message;
                app.log(['Render failed: ' ME.message],'error');
                app.setStatus('render failed');
            end
            app.syncInteractions();
        end

        function syncInteractions(app)
            %SYNCINTERACTIONS  Drag rotates a 3D plot, without arming a mode.
            %   ensureAxes and mirrorAxes both cla(...,'reset'), which restores
            %   the axes to factory defaults and takes Interactions with it.
            %   MATLAB then installs the set that suits the axes AT THAT
            %   MOMENT, which is a flat, empty one -- so every 3D plot came up
            %   with pan on drag and rotate only reachable from the hover
            %   toolbar. Re-assert it after the render, when the view is known.
            if isempty(app.Ax) || ~isvalid(app.Ax), return, end
            if ~isa(app.Ax,'matlab.ui.control.UIAxes'), return, end
            v = app.Ax.View;
            is3 = ~(abs(v(1)) < 1e-6 && abs(v(2) - 90) < 1e-6);

            % FIRST: leave no toolbar mode engaged or half-engaged. An earlier
            % version pressed the Rotate 3D button here to "arm" the mode.
            % Setting a ToolbarStateButton's Value programmatically changes how
            % it LOOKS without firing its callback, so the toolbar believed a
            % mode was on while none was installed -- measured: button Value
            % on, the rotate mode object Enable off. A believed-but-absent mode
            % still suppresses the interactions below, which is why the button
            % appeared active and did nothing until it was clicked twice: the
            % first click only put the two back in step.
            %
            % So release the buttons and clear the modes, and let Interactions
            % do the work. Order matters -- this runs BEFORE the assignment
            % below, because clearing a mode restores that axes' default
            % interactions and would otherwise throw the assignment away.
            try
                tb = app.Ax.Toolbar;
                if ~isempty(tb) && isvalid(tb)
                    for b = tb.Children'
                        if isa(b,'matlab.ui.controls.ToolbarStateButton') && ...
                                strcmp(char(string(b.Value)),'on')
                            b.Value = matlab.lang.OnOffSwitchState(false);
                        end
                    end
                end
            catch, end
            f = ancestor(app.Ax,'figure');
            if ~isempty(f)
                try, rotate3d(f,'off'); catch, end
                try, pan(f,'off');      catch, end
                try, zoom(f,'off');     catch, end
            end

            % THEN the interactions, so a drag does something sensible even if
            % the mode below cannot be engaged on this release.
            try
                if is3
                    app.Ax.Interactions = ...
                        [rotateInteraction zoomInteraction dataTipInteraction];
                else
                    app.Ax.Interactions = ...
                        [panInteraction zoomInteraction dataTipInteraction];
                end
            catch
                % older releases without one of these interaction objects
                try, app.Ax.Interactions = [zoomInteraction dataTipInteraction]; catch, end
            end

            % The Rotate 3D button is deliberately NOT lit. In a uifigure it is
            % not a switch this code owns: the legacy modes are not installed
            % there, and both routes to lighting it -- assigning btn.Value, and
            % rotate3d(ax,'on') -- were measured to set the button while the
            % mode object stayed Enable=off. A lit button with no mode behind
            % it is worse than an unlit one, because the toolbar then behaves
            % as though a mode were active and swallows the interactions above:
            % that is exactly the bug where rotating took two clicks, the first
            % only putting button and mode back in step.
            %
            % Interactions are the supported mechanism here and need no mode --
            % a drag rotates straight away with the icon unlit. For a window
            % where Rotate 3D really is a mode, Pop out figure gives a standard
            % MATLAB figure, where rotate3d works properly.
        end

        function h = panelH(app, nrows)
            %PANELH  How tall a titled panel of nrows input rows needs to be.
            %   Title bar, top and bottom padding, the rows themselves and the
            %   spacing between them. Writing it once means a panel cannot
            %   drift out of step with what it holds, and adding a row to a
            %   panel is a change in one number rather than two.
            h = 22 + 8 + nrows*app.ROW_H + max(0, nrows-1)*4;
        end

        function [az, el] = faceSectionAngles(app, sec)
            %FACESECTIONANGLES  Camera angles that put the plane normal at you.
            %   MATLAB places the camera for view(az,el) along
            %       [sin(az)cos(el), -cos(az)cos(el), sin(el)]
            %   so solving that for the section normal points the green arrow
            %   out of the screen. Dead-on would flatten the very thing this
            %   picture exists to show -- that the plane cuts a solid block --
            %   so the camera is then swung off the normal: 30 degrees in
            %   azimuth, and elevation eased toward a comfortable 20 by at most
            %   18. That leaves the normal about a third of a right angle off
            %   the line of sight, which still reads as facing you.
            n = sec.n(:).';
            n = n / norm(n);
            el = asind(max(-1, min(1, n(3))));
            az = atan2d(n(1), -n(2));
            az = mod(az + 30 + 180, 360) - 180;
            el = el + max(-18, min(18, 20 - el));
            el = max(-90, min(90, el));
        end

        function plotMain(app, kind)
            m = app.Model; R = m.results;
            % A local copy, so this reaches every m.rgn below without touching
            % the model. With a model built the two are the same value; with
            % none, only the two previews can draw at all, and they should
            % follow the fields.
            m.rgn = app.liveRgn();
            [fnm, box2] = app.viewData();
            al = app.AlphaSld.Value; lw = app.LWSpin.Value;
            is3 = iscell(fnm);
            gn = app.GridSpin.Value;
            age = '=[';
            if app.GridCB.Value, age = [age '+']; end

            isSec = strcmp(kind,'Section plane');
            isBand = strcmp(kind,'Mapped planes');
            if isSec, secGeom = app.sectionGeometry(m.rgn); else, secGeom = []; end
            % a section plot is a 3D scene, so renderVia should apply the
            % azimuth/elevation controls and lighting to it like any other
            app.renderVia(@() draw(), is3 || isSec || isBand);
            if isSec, app.tidySectionAxes(secGeom); end

            function draw()
                switch kind
                    case {'Flow | solution','Flow | backbone','Flow | pipes'}
                        % ADFNE 1.5 draws these as cylinders sized for a unit
                        % box, so scale the radius with the real domain.
                        rad = 0.012 * mean([m.rgn(2)-m.rgn(1), ...
                                            m.rgn(4)-m.rgn(3), ...
                                            max(m.rgn(6)-m.rgn(5), eps)]);
                        switch kind
                            case 'Flow | backbone', what = 'b';
                            case 'Flow | pipes',    what = 'p';
                            otherwise,              what = 'seniq';
                        end
                        % note: no 'sub' argument - Draw's sub=0 path calls
                        % clf, which would delete the axes renderVia mirrors
                        Draw(R.flow, 'what', what, 'r', rad);
                    case 'Section plane'
                        % Where the 2D view actually cuts the block. Drawn from
                        % the live field values, so it works before anything has
                        % been generated - which is when you need to see it.
                        sc = app.sectionGeometry(m.rgn);
                        Draw('cub', m.rgn([1 3 5 2 4 6]), 'fc',[0.45 0.5 0.55], ...
                             'fa',0.06, 'ec',[0.35 0.35 0.35]);
                        hold on
                        % the surrounding fractures, coloured by set like
                        % every other view, and switchable off so the face and
                        % its traces can be read on their own
                        showDFN = isempty(app.Show3DCB) || app.Show3DCB.Value;
                        if showDFN && iscell(m.fnm) && ~isempty(m.fnm)
                            p3 = m.fnm;
                            sid3 = m.setid;
                            if isempty(sid3), sid3 = ones(numel(p3),1); end
                            [p3, sid3] = app.clipToSection(p3, sid3, sc);
                            u3 = unique(sid3(sid3 > 0));
                            for kk = 1:numel(u3)
                                app.patchPolys(p3(sid3 == u3(kk)), ...
                                    app.labelColour(u3(kk)), min(al, 0.18));
                            end
                        end
                        if size(sc.face,1) >= 3
                            patch(sc.face(:,1), sc.face(:,2), sc.face(:,3), ...
                                [0.10 0.45 0.80], 'FaceAlpha',0.30, ...
                                'EdgeColor',[0.06 0.30 0.60], 'LineWidth',2);
                        end
                        % the plane normal: which way the face looks. Short and
                        % thick so it reads as a marker on the face rather than
                        % a line competing with the fractures.
                        L = 0.14 * norm(m.rgn([2 4 6]) - m.rgn([1 3 5]));
                        quiver3(sc.p0(1), sc.p0(2), sc.p0(3), ...
                            L*sc.n(1), L*sc.n(2), L*sc.n(3), 0, ...
                            'Color',[0.15 1.00 0.15], 'LineWidth',4, ...
                            'MaxHeadSize',1.2);
                        % and the traces it cuts, if there is a model
                        if isfield(m,'sec') && ~isempty(m.sec) && ...
                                isfield(m.sec,'traces3d') && ~isempty(m.sec.traces3d)
                            X = m.sec.traces3d;
                            ts = m.sec.setid;
                            if isempty(ts), ts = ones(size(X,1),1); end
                            % each trace in its joint set's colour, matching
                            % the 3D model and the 2D section exactly
                            for kk = unique(ts(ts > 0))'
                                f = (ts == kk);
                                plot3([X(f,1) X(f,4)]', [X(f,2) X(f,5)]', ...
                                      [X(f,3) X(f,6)]', '-', ...
                                      'Color', app.labelColour(kk), 'LineWidth', 2.2);
                            end
                        end
                        SetAxes3D([m.rgn(1) m.rgn(3) m.rgn(5)], ...
                                  [m.rgn(2) m.rgn(4) m.rgn(6)]);
                        % pin the limits to the domain. SetAxes3D only draws
                        % the coloured axis lines; without this MATLAB
                        % autoscales to whatever was drawn and the box floats
                        % inside a larger frame (-5..10 for a 0..10 domain).
                        xlim([m.rgn(1) m.rgn(2)]);
                        ylim([m.rgn(3) m.rgn(4)]);
                        zlim([m.rgn(5) m.rgn(6)]);
                        % the camera is left to the view controls: pinning it
                        % here threw away any rotation the moment anything
                        % triggered a redraw
                        if iscell(m.fnm)
                            extra = sprintf('   -   %d fractures, %d cut it', ...
                                numel(m.fnm), size(m.sec.lines,1));
                        else
                            extra = '';
                        end
                        title(sprintf(['section plane   dip %g / dipdir %g / ' ...
                            'offset %g   -   face %.4g x %.4g%s'], sc.dip, sc.ddir, ...
                            sc.off, sc.box(2)-sc.box(1), sc.box(4)-sc.box(3), extra));
                    case 'Mapped planes'
                        % What "fit to these planes" is pointing at: the band
                        % and the joint planes in it, drawn from the live
                        % fields so it works before anything is generated.
                        b = app.bandGeometry(m.rgn);
                        app.harvestCondTable();
                        PP = {};
                        try, PP = app.planesFor(b); catch, end %#ok<CTCH>
                        Draw('cub', m.rgn([1 3 5 2 4 6]), 'fc',[0.45 0.5 0.55], ...
                             'fa',0.06, 'ec',[0.35 0.35 0.35]);
                        hold on
                        showDFN = isempty(app.Show3DCB) || app.Show3DCB.Value;
                        if showDFN && iscell(m.fnm) && ~isempty(m.fnm)
                            app.patchPolys(m.fnm, [0.55 0.60 0.68], min(al, 0.10));
                        end
                        for F = {b.faceLo, b.faceHi}
                            if size(F{1},1) >= 3
                                patch(F{1}(:,1), F{1}(:,2), F{1}(:,3), ...
                                    [0.10 0.45 0.80], 'FaceAlpha',0.12, ...
                                    'EdgeColor',[0.06 0.30 0.60], 'LineWidth',1.5);
                            end
                        end
                        if ~isempty(PP), app.patchPolys(PP, app.REG_FACE, 0.8); end
                        SetAxes3D([m.rgn(1) m.rgn(3) m.rgn(5)], ...
                                  [m.rgn(2) m.rgn(4) m.rgn(6)]);
                        xlim([m.rgn(1) m.rgn(2)]); ylim([m.rgn(3) m.rgn(4)]);
                        zlim([m.rgn(5) m.rgn(6)]);
                        if isempty(PP)
                            title(['mapped planes: nothing to fit to yet - import ' ...
                                   'a file, or fill the table below']);
                        else
                            ain = 0;
                            for kk = 1:numel(PP), ain = ain + app.areaInBand(PP{kk}, b); end
                            title(sprintf(['mapped planes: %d in a band %.3g thick ' ...
                                '(dip %g / dipdir %g)   -   P32 in band %.4g'], ...
                                numel(PP), b.thk, b.dip, b.ddir, ain / max(b.vol, eps)));
                        end
                    case 'Trace map'
                        % What "fit to these traces" is pointing at. It goes
                        % through traceMapFor, the same call FIT makes, so an
                        % imported map is exactly the set FIT reads, and a
                        % synthetic one is the same seeded draw.
                        sc = app.sectionGeometry(m.rgn);
                        T  = app.traceMapFor(sc, true);
                        % Outline, not a filled patch. mirrorAxes copies the
                        % hidden figure's children through flipud, which
                        % inverts draw order in a 2D axes, so a filled face
                        % landed on top of the traces and hid every one that
                        % fell on it -- the picture showed 54 traces and an
                        % empty box. An outline cannot occlude anything.
                        if size(sc.faceUV,1) >= 3
                            patch(sc.faceUV(:,1), sc.faceUV(:,2), [1 1 1], ...
                                'FaceColor','none', ...
                                'EdgeColor',[0.10 0.45 0.80], 'LineWidth',1.6);
                        end
                        hold on
                        lim = sc.box;
                        if isempty(T)
                            title(['trace map: nothing to fit to yet - ' ...
                                   'import a face, or fill the table below']);
                        else
                            plot([T(:,1) T(:,3)]', [T(:,2) T(:,4)]', '-', ...
                                'Color', app.REG_FACE, 'LineWidth', max(1.2, lw));
                            % the window P21 is actually measured over, which
                            % is the traces' own extent clipped to the face --
                            % not the whole face, and the difference is what
                            % used to send the fitted count to a third of truth
                            [win, ~, cov] = app.mapWindow(T, sc);
                            plot(win([1 2 2 1 1]), win([3 3 4 4 3]), '--', ...
                                'Color',[0.30 0.30 0.30], 'LineWidth',1);
                            ln = sqrt(sum((T(:,3:4) - T(:,1:2)).^2, 2));
                            % A map in the wrong units, or for a bigger domain
                            % than this one, lands entirely off the face. Say
                            % so: the first version framed the face and clipped
                            % the traces away, so it read "54 traces" over an
                            % empty box, which is the confusion this plot was
                            % built to end.
                            % A trace clipped exactly to the boundary is ON
                            % the face; without a tolerance the round-off
                            % from that clip reported it as off.
                            tu = 1e-6 * max(1, sc.box(2)-sc.box(1));
                            tv = 1e-6 * max(1, sc.box(4)-sc.box(3));
                            off = any(T(:,[1 3]) < sc.box(1)-tu | ...
                                      T(:,[1 3]) > sc.box(2)+tu, 2) | ...
                                  any(T(:,[2 4]) < sc.box(3)-tv | ...
                                      T(:,[2 4]) > sc.box(4)+tv, 2);
                            if any(off)
                                title(sprintf(['trace map: %d traces, %d off ' ...
                                    'the face - check the units and the ' ...
                                    'domain'], size(T,1), sum(off)));
                            else
                                title(sprintf(['trace map: %d traces, mean ' ...
                                    'length %.4g, window %.0f%% of face'], ...
                                    size(T,1), mean(ln), 100*cov));
                            end
                            % frame the face AND the map, so a mismatch is
                            % visible rather than cropped out of the picture
                            lim(1) = min(lim(1), min(T(:,[1 3]),[],'all'));
                            lim(2) = max(lim(2), max(T(:,[1 3]),[],'all'));
                            lim(3) = min(lim(3), min(T(:,[2 4]),[],'all'));
                            lim(4) = max(lim(4), max(T(:,[2 4]),[],'all'));
                        end
                        axis equal
                        pad = 0.04 * max([lim(2)-lim(1), lim(4)-lim(3), eps]);
                        xlim([lim(1)-pad, lim(2)+pad]);
                        ylim([lim(3)-pad, lim(4)+pad]);
                        xlabel('u   (across the face)');
                        ylabel('v   (up the face)');
                    case 'Variogram'
                        plot(R.varioDist, R.varioGamma, 'o-', 'LineWidth',1.4, ...
                            'Color',[0.09 0.35 0.60], 'MarkerFaceColor',[1 1 1]);
                        grid on
                        xlabel('separation distance'); ylabel('semivariance \gamma');
                        title('Variogram');
                    case 'Kriging map'
                        imagesc(R.kriging); axis image; set(gca,'YDir','normal');
                        if app.CbarCB.Value, colorbar; end
                        title('Kriging estimate');
                    case 'Upscaled grid'
                        imagesc(R.upscaled); axis image; set(gca,'YDir','normal');
                        if app.CbarCB.Value, colorbar; end
                        title(sprintf('Upscaled %s (geometric)', R.upscaledFrom));
                    case 'Fracture network'
                        CL = app.colorLabels();
                        if app.isCategorical(CL)
                            app.drawByLabel(fnm, CL, is3, al, lw, m.rgn, box2);
                        elseif is3
                            if ~isempty(CL), CL = app.safeLabels(CL); end
                            DrawPolys3D(fnm, CL, [0.20 0.42 0.68 al], true);
                        else
                            DrawLines2D(fnm, CL, [0 0 0], age);
                        end
                    case 'Clusters'
                        if app.isCategorical(m.La)
                            app.drawByLabel(fnm, m.La, is3, al, lw, m.rgn, box2);
                        elseif is3
                            DrawPolys3D(fnm, app.safeLabels(m.La), [0.2 0.4 0.7 al], true);
                        else
                            DrawLines2D(fnm, m.La, [0 0 0], age);
                        end
                    case 'Largest cluster'
                        lp = m.La(m.La>0); mc = mode(lp);
                        keep = double(m.La) == mc;
                        DrawPolys3D(fnm(keep), [], [0.82 0.16 0.16 al], true);
                    case 'Backbone'
                        DrawLines2D(R.backbone, [], [0 0 0], age);
                    case 'Isolated vs connected'
                        b = R.isolated;
                        DrawLines2D(fnm(~b,:), [], [0.10 0.35 0.65], age); hold on
                        DrawLines2D(fnm(b,:),  [], [0.75 0.75 0.75], age);
                    case 'Density map',        app.imgOverlay(R.density, R.densityX, R.densityY, fnm, box2);
                    case 'Connectivity field', app.imgOverlay(R.CF, R.CFX, R.CFY, fnm, box2);
                    case 'Generalised CF',     app.imgOverlay(R.GCF, R.GCFX, R.GCFY, fnm, box2);
                    case 'Connectivity index', app.imgOverlay(R.CI, R.CIX, R.CIY, fnm, box2);
                    case 'P21 map',            app.imgOverlay(R.P21, R.P21X, R.P21Y, fnm, box2);
                    case 'P22 map',            app.imgOverlay(R.P22, R.P22X, R.P22Y, fnm, box2);
                    case 'Density contours'
                        app.contourOverlay(R.density, R.densityX, R.densityY, fnm, gn);
                    case 'CF contours'
                        app.contourOverlay(R.CF, R.CFX, R.CFY, fnm, gn);
                    case 'Intersection points'
                        DrawLines2D(fnm, [], [0.6 0.6 0.6], age); hold on
                        P = R.xts;
                        plot(P(:,1), P(:,2), 'o', 'MarkerSize',4, ...
                            'MarkerFaceColor',[0.85 0.2 0.2],'MarkerEdgeColor','none');
                    case 'Intersection traces'
                        DrawPolys3D(fnm, [], [0.55 0.62 0.72 0.25], true); hold on
                        for e = 1:numel(R.xts)
                            X = R.xts{e};
                            plot3(X(:,1),X(:,2),X(:,3),'-','Color',[0.75 0.1 0.1],'LineWidth',max(lw,2));
                        end
                    case 'Traces on plane'
                        for e = 1:numel(R.traces)
                            X = R.traces{e};
                            plot3(X(:,1),X(:,2),X(:,3),'-','Color',[0.1 0.3 0.7],'LineWidth',max(lw,1.5));
                            hold on
                        end
                        SetAxes3D([m.rgn(1) m.rgn(3) m.rgn(5)],[m.rgn(2) m.rgn(4) m.rgn(6)]);
                    case 'Centroids'
                        C = R.centroids;
                        plot3(C(:,1),C(:,2),C(:,3),'.','MarkerSize',12,'Color',[0.15 0.35 0.7]);
                        hold on
                        SetAxes3D([m.rgn(1) m.rgn(3) m.rgn(5)],[m.rgn(2) m.rgn(4) m.rgn(6)]);
                    case 'Pipe model'
                        pip = R.pipes; cas = R.pipeCluster;
                        lp = cas(cas>0);
                        if isempty(lp), mc = 0; else, mc = mode(lp); end
                        hold on
                        for i = 1:size(pip,1)
                            if cas(i) == mc, fc = [0.85 0.10 0.10]; a2 = 1;
                            else,            fc = [0.72 0.72 0.72]; a2 = 0.35; end
                            drawCylinder([pip(i,:), 0.006], 12, 'FaceColor', fc, 'FaceAlpha', a2);
                        end
                        C = R.centroids;
                        plot3(C(:,1),C(:,2),C(:,3),'k.','MarkerSize',6);
                        SetAxes3D([m.rgn(1) m.rgn(3) m.rgn(5)],[m.rgn(2) m.rgn(4) m.rgn(6)]);
                end
                % The trace map draws the face outline itself, which is the
                % same rectangle: a second one on top of it is noise.
                if app.BoxCB.Value && ~is3 && ~strcmp(kind,'Trace map')
                    hold on; drawBox(box2,'k-','LineWidth',1.2);
                end
            end
        end

        function [ds, dds] = orient(~, plys)
            % Orientation3D + the normalisation ADFNE applies in PolyInfo3D:
            % dip folded into [0, pi/2], dip direction into [0, 2*pi).
            [ds, dds] = Orientation3D(plys);
            ds  = FixZero(ds);
            dds = FixZero(dds);
            dds = mod(2*pi + dds, 2*pi);
            f   = (ds <= 0);
            ds(f) = ds(f) + pi/2;
        end

        function S = safeLabels(~, L)
            % DrawPolys3D indexes a 64-entry colormap as
            %   cmap(int32(La(i)/max(La)*64), :)
            % which lands on 0 for labels <= 0 and for small labels when there
            % are many clusters. Remap to a range that is always in [1, 64],
            % keeping negatives (isolated fractures) as -1 so ADFNE greys them.
            L = double(L(:));
            S = -ones(numel(L), 1);
            pos = L > 0;
            if ~any(pos), return; end
            [u, ~, ic] = unique(L(pos));
            cnt = accumarray(ic, 1);
            [~, ord] = sort(cnt, 'ascend');       % biggest cluster -> highest index
            rank = zeros(numel(u), 1);
            rank(ord) = 1:numel(u);
            k = numel(u);
            if k > 64                              % compress into 64 usable slots
                rank = max(1, ceil(rank / k * 64));
            end
            S(pos) = rank(ic);
        end

        function c = labelColour(~, k)
            %LABELCOLOUR  The colour for label k, anywhere in the app.
            %   Indexed by the label VALUE, not by its rank among the labels
            %   that happen to be present. Set 3 is the same colour in the 3D
            %   model, on the 2D section and in the intersect view, even when
            %   set 2 puts no traces on that particular face.
            k = max(1, round(double(k)));
            cm = lines(max(k, 7));
            c = cm(k, :);
        end

        function [nc, big, iso] = clusterStats(~, La)
            %CLUSTERSTATS  Groups, largest group, and how many stand alone.
            %   ADFNE labels a connected group with a positive number and every
            %   isolated fracture with its own NEGATIVE index, so max(La) is
            %   the number of groups only when at least one exists -- with a
            %   fully disconnected network it is -1, and three analyses were
            %   reporting "-1 clusters".
            La = double(La(:));
            pos = La(La > 0);
            iso = sum(La <= 0);
            if isempty(pos)
                nc = 0; big = 0; return
            end
            u = unique(pos);
            nc = numel(u);
            big = max(arrayfun(@(x) sum(La == x), u));
        end

        function s = clusterSummary(app, La)
            %CLUSTERSUMMARY  One line saying what the labels actually contain.
            [nc, big, iso] = app.clusterStats(La);
            n = numel(La);
            if nc == 0
                s = sprintf(['Clusters: none. No two fractures intersect, so ' ...
                    'all %d are isolated and colouring by cluster is one ' ...
                    'colour. Larger sizes or a higher count will connect them.'], n);
            else
                s = sprintf(['Clusters: %d connected group(s), largest %d ' ...
                    'fractures, %d of %d isolated.'], nc, big, iso, n);
            end
        end

        function La = ensureClusters(app)
            %ENSURECLUSTERS  Cluster labels, computed if nobody has yet.
            %   Colouring by cluster used to need an intersection analysis run
            %   first and said nothing when there was none -- it just drew one
            %   colour, which reads as "everything is one cluster". It is the
            %   same call the analysis makes, so make it here rather than
            %   leaving the user to guess the precondition.
            La = app.Model.La;
            if ~isempty(La), return, end
            fnm = app.viewData();
            if isempty(fnm), return, end
            try
                if iscell(fnm), [~, ~, La] = PolysX3D(fnm);
                else,           La = LinesToClusters2D(fnm);
                end
            catch ME
                app.log(['Could not work out clusters: ' ME.message], 'warn');
                La = []; return
            end
            app.Model.La = La;
            app.log(app.clusterSummary(La), 'ok');
        end

        function tf = isCategorical(~, L)
            %ISCATEGORICAL  Few enough distinct labels to give each its own hue.
            if isempty(L), tf = false; return, end
            u = unique(double(L(L > 0)));
            tf = ~isempty(u) && numel(u) <= 12;
        end

        function drawByLabel(app, fnm, L, is3, al, lw, rgn, box2)
            %DRAWBYLABEL  Colour fractures by label from a categorical palette.
            %   Neither ADFNE drawer can do this properly on a modern release:
            %   DrawPolys3D indexes rows 1..64 of what is now a 256-entry
            %   colormap, so every colour lands in the blue quarter of jet, and
            %   DrawLines2D picks rand(3,1) per label, so the colours are poor
            %   and change on every redraw. lines() is built for exactly this
            %   and is stable across renders.
            L = double(L(:));
            u = unique(L(L > 0));
            hold on
            grey = (L <= 0);                        % isolated / unlabelled
            if any(grey)
                if is3
                    app.patchPolys(fnm(grey), [0.62 0.62 0.62], al * 0.6);
                else
                    [X, Y] = LinesToXYnan2D(fnm(grey, :));
                    plot(X, Y, '-', 'Color', [0.62 0.62 0.62], 'LineWidth', lw);
                end
            end
            for k = 1:numel(u)
                sel = (L == u(k));
                c = app.labelColour(u(k));
                if is3
                    app.patchPolys(fnm(sel), c, al);
                else
                    [X, Y] = LinesToXYnan2D(fnm(sel, :));
                    plot(X, Y, '-', 'Color', c, 'LineWidth', max(lw, 1.2));
                end
            end
            if is3
                SetAxes3D([rgn(1) rgn(3) rgn(5)], [rgn(2) rgn(4) rgn(6)]);
            else
                axis image
                axis([box2(1) box2(2) box2(3) box2(4)]);
            end
        end

        function patchPolys(~, plys, rgb, alpha)
            %PATCHPOLYS  Draw a set of polygons as ONE patch object.
            %   A patch per fracture is what made rendering slow: 1350 of them
            %   took four seconds, nearly all of it graphics-object overhead
            %   rather than drawing. Faces/Vertices with NaN padding lets
            %   polygons of different vertex counts share a single object.
            n = numel(plys);
            if n == 0, return, end
            nv = zeros(n,1);
            for i = 1:n
                q = plys{i};
                if size(q,1) >= 3 && size(q,2) == 3, nv(i) = size(q,1); end
            end
            keep = nv > 0;
            if ~any(keep), return, end
            plys = plys(keep); nv = nv(keep);
            m = numel(plys);
            V = zeros(sum(nv), 3);
            F = nan(m, max(nv));
            k = 0;
            for i = 1:m
                q = nv(i);
                V(k+1:k+q, :) = plys{i};
                F(i, 1:q) = (k+1):(k+q);
                k = k + q;
            end
            patch('Vertices', V, 'Faces', F, 'FaceColor', rgb, ...
                  'FaceAlpha', alpha, 'EdgeColor', [0.30 0.30 0.30], ...
                  'LineWidth', 0.25);
        end

        function L = colorLabels(app)
            [~, ~, sid] = app.viewData();
            switch app.ColorDD.Value
                case 'cluster', L = app.ensureClusters();
                case 'set',     L = sid;
                otherwise,      L = [];
            end
            if isempty(L), L = []; end
        end

        function imgOverlay(app, M, x, y, fnm, box2)
            imagesc(x, y, M); set(gca,'YDir','normal'); hold on
            if ~iscell(fnm)
                [X,Y] = LinesToXYnan2D(fnm);
                plot(X, Y, '-', 'Color',[0 0 0], 'LineWidth', app.LWSpin.Value*0.7);
            end
            axis image; axis([box2(1) box2(2) box2(3) box2(4)]);
            if app.CbarCB.Value, colorbar; end
        end

        function contourOverlay(app, M, gx, gy, fnm, gn)
            % contour over the grid's OWN extent. Stretching it across the
            % whole face was what made a map of one corner look like a map
            % of everything.
            S = Smooth(Resize2D(M, 3*gn, 3*gn), 1);
            [I,J] = size(S);
            sx = linspace(gx(1),gx(2),J); sy = linspace(gy(1),gy(2),I);
            contourf(sx, sy, S, 14, 'LineStyle','none'); hold on
            if ~iscell(fnm)
                [X,Y] = LinesToXYnan2D(fnm);
                plot(X, Y, '-', 'Color',[1 1 1], 'LineWidth', app.LWSpin.Value*0.8);
            end
            axis image
            if app.CbarCB.Value, colorbar; end
        end

        function plotRose(app)
            %PLOTROSE  Orientation rose of whatever the current view shows.
            %   In 3D that is the dip direction of the fractures themselves.
            %   In 2D it is the direction of the traces in the plane of the
            %   face - which is what you measure off a face, and what it used
            %   to NOT show: it read Model.fnm, always the 3D polygons, so the
            %   2D rose was quietly a 3D rose.
            fnm = app.viewData();
            if iscell(fnm)
                [~, dds] = app.orient(fnm); a = dds(:);
                ttl = 'Fracture orientation rose  (3D dip direction)';
            else
                dx = fnm(:,3)-fnm(:,1); dy = fnm(:,4)-fnm(:,2);
                a = mod(atan2(dy,dx), pi); a = [a; a+pi];
                ttl = 'Trace orientation rose  (in the plane of the face)';
            end
            app.ensureAxes('polar');
            polarhistogram(app.Ax, a, 36, 'FaceColor',[0.20 0.42 0.68],'FaceAlpha',0.85);
            title(app.Ax, ttl);
        end

        function plotStereonet(app)
            %PLOTSTEREONET  Lower-hemisphere equal-area plot of fracture poles,
            %   in the model's own XY frame.
            %
            %   It used to place a pole at (R sin, R cos) with N at the top,
            %   the compass layout - but the app measures dip direction
            %   anticlockwise from +X, not clockwise from north. Mixing the
            %   two mirrored the plot: poles rotating anticlockwise in the
            %   model came out rotating clockwise on the net. Angles between
            %   poles survive a mirror, so it looked plausible, but the
            %   chirality was reversed and a conjugate pair read backwards.
            %   Plotted in the model frame instead: +X right, +Y up, which is
            %   also the frame the rose diagram uses.
            fnm = app.Model.fnm;
            [ds, dds] = app.orient(fnm);
            pl = pi/2 - ds; tr = mod(dds + pi, 2*pi);
            Rr = sqrt(2) * sin((pi/2 - pl)/2);
            px = Rr .* cos(tr); py = Rr .* sin(tr);
            app.renderVia(@() draw(), false);
            function draw()
                tt = linspace(0,2*pi,300);
                plot(cos(tt), sin(tt), 'k-','LineWidth',1); hold on
                sid = [];
                if isfield(app.Model,'setid'), sid = app.Model.setid; end
                if ~isempty(sid) && numel(sid) == numel(px) && strcmp(app.ColorDD.Value,'set')
                    cmap = lines(max(sid));
                    for s = 1:max(sid)
                        k = sid == s;
                        plot(px(k), py(k), '.', 'MarkerSize',11,'Color',cmap(s,:));
                    end
                else
                    plot(px, py, '.', 'MarkerSize',11,'Color',[0.15 0.35 0.75]);
                end
                plot(0,0,'k+');
                text(1.10, 0, '+X','HorizontalAlignment','center', ...
                     'FontWeight','bold','Color',[0.35 0.35 0.35]);
                text(0, 1.10, '+Y','HorizontalAlignment','center', ...
                     'FontWeight','bold','Color',[0.35 0.35 0.35]);
                axis equal off
                title(['Fracture poles | equal-area, lower hemisphere, ' ...
                       'model XY frame']);
            end
        end

        function plotHist(app, what)
            % size and dip are 3D properties, so they come from the model
            % itself; length is a trace length, so it comes from the section
            fnm = app.Model.fnm; R = app.Model.results;
            switch what
                case 'length'
                    if isfield(R,'lengths')
                        v = R.lengths;
                    else
                        % Model.fnm is a cell of 3D polygons - indexing it as
                        % a line matrix threw, and renderPlot logged it and
                        % carried on, so this plot looked fine and drew nothing
                        L = app.viewData();
                        if iscell(L)
                            error(['Trace lengths need the 2D section view. ' ...
                                   'Switch View to 2D, or use Size histogram ' ...
                                   'for the 3D fracture sizes.']);
                        end
                        v = hypot(L(:,3)-L(:,1), L(:,4)-L(:,2));
                    end
                    ttl = 'Trace length distribution  (on the section)';
                    xl = 'trace length';
                case 'size'
                    if isfield(R,'sizes'), v = R.sizes; else, v = Size3D(fnm); end
                    ttl = 'Fracture size distribution  (3D)'; xl = 'size';
                otherwise
                    if isfield(R,'dip'), v = rad2deg(R.dip);
                    else, d = app.orient(fnm); v = rad2deg(d); end
                    ttl = 'Dip distribution  (3D)'; xl = 'dip (deg)';
            end
            app.renderVia(@() draw(), false);
            function draw()
                histogram(v, 30, 'FaceColor',[0.20 0.42 0.68]); grid on
                xlabel(xl); ylabel('count'); title(ttl);
            end
        end

        function plotClusterSizes(app)
            La = app.Model.La;
            if isempty(La), return; end
            k = double(max(La));
            if k < 1, return; end
            cnt = histcounts(double(La(La>0)), 0.5:1:k+0.5);
            cnt = sort(cnt,'descend');
            app.renderVia(@() draw(), false);
            function draw()
                bar(cnt, 'FaceColor',[0.20 0.42 0.68]); grid on
                xlabel('cluster rank'); ylabel('fractures in cluster');
                title(sprintf('Cluster size distribution  (%d clusters)', k));
                set(gca,'YScale','log');
            end
        end

        function plotConnMatrix(app)
            cm = app.Model.results.cm;
            app.renderVia(@() draw(), false);
            function draw()
                spy(sparse(cm), 4);
                title(sprintf('Connectivity matrix  (%d fractures, %d links)', ...
                    size(cm,1), nnz(cm)/2));
                xlabel('fracture'); ylabel('fracture');
            end
        end

        function plotGraph(app)
            G = app.Model.results.graph;
            app.renderVia(@() draw(), false);
            function draw()
                p = plot(G, 'Layout','force','NodeColor',[0.20 0.42 0.68], ...
                    'EdgeColor',[0.6 0.6 0.6],'MarkerSize',4,'NodeLabel',{});
                p.LineWidth = 0.5;
                title(sprintf('Fracture topology graph  (%d nodes, %d edges)', ...
                    numnodes(G), numedges(G)));
                axis off
            end
        end
    end

    %% --------------------------------------------------------- render plumbing
    methods (Access = public, Hidden = true)

        function ensureAxes(app, kind)
            want = 'matlab.ui.control.UIAxes';
            if strcmp(kind,'polar'), want = 'matlab.graphics.axis.PolarAxes'; end
            if ~isempty(app.Ax) && isvalid(app.Ax) && isa(app.Ax, want)
                if strcmp(kind,'polar'), cla(app.Ax); else, cla(app.Ax,'reset'); end
                return
            end
            if ~isempty(app.Ax) && isvalid(app.Ax), delete(app.Ax); end
            if strcmp(kind,'polar')
                app.Ax = polaraxes('Parent', app.PlotGrid);
            else
                app.Ax = uiaxes(app.PlotGrid);
                try
                    app.Ax.Interactions = [rotateInteraction zoomInteraction dataTipInteraction];
                catch
                    try, app.Ax.Interactions = [zoomInteraction dataTipInteraction]; catch, end
                end
            end
            app.Ax.Layout.Row = 1; app.Ax.Layout.Column = 1;
        end

        function renderVia(app, drawFcn, is3d)
            % Run an ADFNE (or plain MATLAB) drawing routine in a hidden classic
            % figure, then mirror the result into the app's uiaxes. This lets the
            % GUI reuse ADFNE's own plotting code, which relies on gca/gcf.
            tmp = figure('Visible','off','Color','w','Position',[100 100 1000 900]);
            cl  = onCleanup(@() delete(tmp));
            ax0 = axes('Parent', tmp); %#ok<LAXES>
            axes(ax0); hold(ax0,'on');
            try
                % 64 rows on purpose: ADFNE indexes cmap(La/max(La)*64), written
                % when MATLAB's default colormap had 64 entries. Modern MATLAB
                % returns 256, which squeezes every label into the bottom
                % quarter of the map - all blue for jet.
                colormap(tmp, feval(app.CmapDD.Value, 64));
            catch
                try, colormap(tmp, app.CmapDD.Value); catch, end
            end
            drawFcn();
            app.ensureAxes('cart');
            app.mirrorAxes(ax0, app.Ax);
            % cla(...,'reset') in ensureAxes drops any custom interactions, so
            % re-arm them every render - otherwise dragging to rotate depends
            % on whatever MATLAB's default set happens to be
            try
                app.Ax.Interactions = [rotateInteraction, zoomInteraction, ...
                                       dataTipInteraction];
            catch
                try, enableDefaultInteractivity(app.Ax); catch, end
            end
            % and a toolbar, so rotating is discoverable rather than something
            % you have to know to try by dragging
            try
                axtoolbar(app.Ax, {'rotate','pan','zoomin','zoomout','restoreview'});
            catch, end
            if is3d
                view(app.Ax, [app.AzSld.Value app.ElSld.Value]);
                if app.LightCB.Value
                    light(app.Ax,'Position',[-1 -1 1]);
                    light(app.Ax,'Position',[1 0.5 0.5]);
                    lighting(app.Ax,'gouraud');
                end
            end
        end

        function mirrorAxes(app, src, dst)
            cla(dst,'reset');
            kids = allchild(src);
            if ~isempty(kids), copyobj(flipud(kids), dst); end
            props = {'XLim','YLim','ZLim','CLim','View','DataAspectRatio', ...
                     'PlotBoxAspectRatio','XDir','YDir','ZDir','XScale','YScale', ...
                     'ZScale','Box','XGrid','YGrid','ZGrid','Projection','Visible', ...
                     'XTick','YTick','ZTick','XColor','YColor','ZColor'};
            for i = 1:numel(props)
                try, dst.(props{i}) = src.(props{i}); catch, end %#ok<CTCH>
            end
            try, dst.Title.String  = src.Title.String;  catch, end
            try, dst.XLabel.String = src.XLabel.String; catch, end
            try, dst.YLabel.String = src.YLabel.String; catch, end
            try, dst.ZLabel.String = src.ZLabel.String; catch, end
            try, colormap(dst, app.CmapDD.Value); catch, end
            try
                cb = findobj(ancestor(src,'figure'),'Type','colorbar');
                if ~isempty(cb) && app.CbarCB.Value, colorbar(dst); end
            catch, end
        end

        function onResetView(app)
            try, app.setView([-35 20]); catch, end
        end

        function onFit(app)
            try, axis(app.Ax,'tight'); catch, end
        end

        function onClearPlot(app)
            app.ensureAxes('cart'); cla(app.Ax,'reset');
            app.setStatus('viewport cleared');
        end

        function onPopOut(app)
            f = figure('Color','w','Name','ADFNE | popped out','NumberTitle','off');
            a = axes('Parent', f); %#ok<LAXES>
            try
                copyobj(flipud(allchild(app.Ax)), a);
                props = {'XLim','YLim','ZLim','CLim','View','DataAspectRatio', ...
                         'XDir','YDir','Box','XGrid','YGrid','ZGrid','Visible'};
                for i = 1:numel(props)
                    try, a.(props{i}) = app.Ax.(props{i}); catch, end %#ok<CTCH>
                end
                a.Title.String = app.Ax.Title.String;
                colormap(f, app.CmapDD.Value);
                app.log('Viewport copied to a standard figure.');
            catch ME
                app.log(['Pop out failed: ' ME.message],'error');
            end
        end

        function onSaveImage(app)
            [fn, pth] = uiputfile({'*.png';'*.pdf';'*.svg'}, 'Save viewport', ...
                fullfile(app.OutDirField.Value,'adfne_view.png'));
            figure(app.Fig);
            if isequal(fn,0), return; end
            try
                fp = fullfile(pth,fn);
                [~,~,e] = fileparts(fp);
                if strcmpi(e,'.svg')
                    app.printCopy(fp, '-dsvg');     % exportgraphics cannot
                else
                    exportgraphics(app.Ax, fp, 'Resolution', 300);
                end
                app.log(['Saved ' fp],'ok');
            catch ME
                app.log(['Save failed: ' ME.message],'error');
            end
        end
    end

    %% ---------------------------------------------------------- exporting
    methods (Access = public, Hidden = true)

        function onBrowseOut(app)
            p = uigetdir(app.OutDirField.Value,'Select output folder');
            figure(app.Fig);
            if isequal(p,0), return; end
            app.OutDirField.Value = p;
        end

        function base = safeBaseName(app)
            %SAFEBASENAME  A base name a file system will accept.
            %   One clear message beats nine cryptic ones. A name with a colon
            %   or a wildcard in it used to fail once per selected format, each
            %   time in whatever words that particular writer happened to use
            %   ("Unable to find file", "Unable to open file for output"),
            %   none of which name the character that caused it.
            base = strtrim(app.BaseNameField.Value);
            if isempty(base)
                uialert(app.Fig,['Type a base name for the exported files. ' ...
                    'Every selected format writes <base name>.<ext>.'], 'Export');
                base = ''; return
            end
            hit = ismember(base, '<>:"/\|?*') | double(base) < 32;
            if any(hit)
                uialert(app.Fig, sprintf(['The base name contains %s, which a ' ...
                    'file name cannot hold.' newline newline 'Use letters, ' ...
                    'digits, spaces, - and _ . The folder above is where the ' ...
                    'files go; this is only their name.'], ...
                    strjoin(cellstr(unique(base(hit))'), ' and ')), 'Export');
                base = ''; return
            end
        end

        function L = sectionLines(app)
            %SECTIONLINES  The traces on the section plane, as an n-by-4 line set.
            %   ADFNE's SaveLinesAsSVG2D and SaveLinesAsHTML2D take a 2D line
            %   network. This app used to hand them Model.fnm and refuse
            %   whenever it was a cell array -- which, since the model became
            %   always-3D, is always, so neither format could ever be written.
            %   The 2D line network this model has is the section: the face.
            L = [];
            m = app.Model;
            if isfield(m,'sec') && isstruct(m.sec) && isfield(m.sec,'lines')
                L = m.sec.lines;
            end
            if isempty(L)
                error('ADFNE:NoTraces', ...
                    ['These two formats write a 2D line network, and the one ' ...
                     'this model has is the traces on the section plane -- ' ...
                     'there are none. Generate a network, and if the face is ' ...
                     'still empty move the section plane so that it cuts the ' ...
                     'domain.']);
            end
        end

        function printCopy(app, fp, driver)
            %PRINTCOPY  Write the viewport through a traditional figure.
            %   exportgraphics refuses SVG ("File format 'svg' is not valid for
            %   export"), which made the SVG entry in the format list fail
            %   every single time it was chosen. print can write it, but only
            %   from a traditional figure, so the viewport is copied into one
            %   first -- the same copy the FIG format already makes.
            tmp = figure('Visible','off','Color','w');
            cl  = onCleanup(@() delete(tmp)); %#ok<NASGU>
            a   = axes('Parent', tmp); %#ok<LAXES>
            copyobj(flipud(allchild(app.Ax)), a);
            props = {'XLim','YLim','ZLim','CLim','View','DataAspectRatio', ...
                     'XDir','YDir','Box','XGrid','YGrid','ZGrid','Visible'};
            for i = 1:numel(props)
                try, a.(props{i}) = app.Ax.(props{i}); catch, end %#ok<CTCH>
            end
            try, a.Title.String = app.Ax.Title.String; catch, end
            try, colormap(tmp, app.CmapDD.Value); catch, end
            print(tmp, driver, fp);
        end

        function onExport(app)
            base = app.safeBaseName();
            if isempty(base), return, end
            outdir = app.OutDirField.Value;
            % An output folder that cannot be made used to throw straight out
            % of the callback, past the per-format error handling below, so a
            % mistyped drive letter produced a raw MATLAB error and no export.
            try
                if ~exist(outdir,'dir'), mkdir(outdir); end
                okdir = logical(exist(outdir,'dir'));
            catch
                okdir = false;
            end
            if ~okdir
                uialert(app.Fig, sprintf(['The output folder does not exist ' ...
                    'and could not be created:' newline '    %s' newline newline ...
                    'Use Browse to pick one that does.'], outdir), 'Export failed');
                return
            end
            fmts = app.FmtList.Value;
            if ischar(fmts), fmts = {fmts}; end
            m = app.Model;
            for i = 1:numel(fmts)
                f = fmts{i};
                try
                    switch f
                        case 'png', exportgraphics(app.Ax, fullfile(outdir,[base '.png']),'Resolution',300);
                        case 'pdf', exportgraphics(app.Ax, fullfile(outdir,[base '.pdf']),'ContentType','vector');
                        case 'svg', app.printCopy(fullfile(outdir,[base '.svg']), '-dsvg');
                        case 'fig'
                            tmp = figure('Visible','off','Color','w');
                            a = axes('Parent',tmp); %#ok<LAXES>
                            copyobj(flipud(allchild(app.Ax)), a);
                            savefig(tmp, fullfile(outdir,[base '.fig'])); delete(tmp);
                        case 'vtk'
                            if ~iscell(m.fnm), error('VTK export needs a 3D polygon model'); end
                            col = repmat([0.3 0.5 0.8], numel(m.fnm), 1);
                            SavePolysToVTK3D(m.fnm, col, fullfile(outdir,[base '.vtk']));
                        case 'asvg'
                            SaveLinesAsSVG2D(fullfile(outdir,[base '_traces.svg']), ...
                                app.sectionLines(), 800, 800, 'black', 1);
                        case 'ahtml'
                            SaveLinesAsHTML2D(fullfile(outdir,[base '_traces.html']), ...
                                app.sectionLines(), 800, 800, 'black', 1);
                        case 'mat'
                            model = m; %#ok<NASGU>
                            save(fullfile(outdir,[base '.mat']), 'model');
                        case 'csv'
                            app.writeCSV(fullfile(outdir,[base '.csv']));
                    end
                    app.log(sprintf('Exported %s -> %s', upper(f), outdir),'ok');
                catch ME
                    app.log(sprintf('Export %s failed: %s', upper(f), ME.message),'error');
                end
            end
        end

        function writeCSV(app, fp)
            m = app.Model;
            if iscell(m.fnm)
                C = Centroids3D(m.fnm);
                [ds, dds] = app.orient(m.fnm);
                sz = Size3D(m.fnm);
                La = app.clusterColumn(numel(m.fnm));
                T = table((1:numel(m.fnm))', C(:,1),C(:,2),C(:,3), rad2deg(ds), rad2deg(dds), sz, double(La(:)), ...
                    'VariableNames',{'id','xc','yc','zc','dip_deg','dipdir_deg','size','cluster'});
            else
                L = m.fnm;
                len = hypot(L(:,3)-L(:,1), L(:,4)-L(:,2));
                ang = rad2deg(mod(atan2(L(:,4)-L(:,2), L(:,3)-L(:,1)), pi));
                La = app.clusterColumn(size(L,1));
                T = table((1:size(L,1))', L(:,1),L(:,2),L(:,3),L(:,4), len, ang, double(La(:)), ...
                    'VariableNames',{'id','x1','y1','x2','y2','length','angle_deg','cluster'});
            end
            writetable(T, fp);
        end

        function La = clusterColumn(app, n)
            % cluster labels as an n-by-1 column; zero-filled when absent or
            % left over from a previous, differently sized model
            La = app.Model.La;
            if isempty(La) || numel(La) ~= n
                La = zeros(n, 1);
            else
                La = double(La(:));
            end
        end

        function onSaveSession(app, target)
            %ONSAVESESSION  Write the session, asking where unless told.
            %   The optional path is what makes this testable: saved-session
            %   compatibility is part of the contract, and a check for it
            %   cannot drive a modal file dialog.
            if nargin >= 2 && ~isempty(target)
                [pth, base, ext] = fileparts(target);
                if isempty(ext), ext = '.mat'; end
                fn = [base ext];
                if isempty(pth), pth = app.OutDirField.Value; end
            else
                [fn, pth] = uiputfile('*.mat','Save session', ...
                    fullfile(app.OutDirField.Value,'adfne_session.mat'));
                figure(app.Fig);
                if isequal(fn,0), return; end
            end
            app.harvestSets();
            session = struct('model',app.Model,'sets',app.SetTable.Data, ...
                'setstore',app.Sets, ...
                'mode',app.ModeDD.Value,'rgn',[app.RgnFields.Value], ...
                'seed',app.SeedSpin.Value,'vars',app.Vars, ...
                'ui',app.uiState()); %#ok<NASGU>
            save(fullfile(pth,fn),'session');
            app.log(['Session saved to ' fullfile(pth,fn)],'ok');
        end

        function u = uiState(app)
            %UISTATE  Everything outside the model that decides what GENERATE
            %   builds and what the 2D view looks at.
            %
            %   Without these a loaded session was not the session. Shape,
            %   facets and the two separation constraints went back to their
            %   defaults, so the same seed and the same joint sets rebuilt a
            %   DIFFERENT rock mass. Worse, the section fields read 90/0/0
            %   while Model.sec still held the plane that had been saved: the
            %   face on screen was the saved one until anything at all was
            %   touched, and then it silently became a different face -- 3
            %   traces where a moment before there had been 13.
            u = struct( ...
                'shape',      app.ShapeDD.Value, ...
                'facets',     app.FacetSpin.Value, ...
                'asep',       app.ASepField.Value, ...
                'dsep',       app.DSepField.Value, ...
                'secdip',     app.SecDipF.Value, ...
                'secdir',     app.SecDirF.Value, ...
                'secoff',     app.SecOffF.Value, ...
                'clip',       app.SecClipDD.Value, ...
                'condsrc',    app.CondSrcDD.Value, ...
                'condtab',    app.TraceSets, ...
                'condon',     app.CondCB.Value, ...
                'condexcl',   app.CondExclCB.Value, ...
                'tracemap',   app.TraceMap, ...
                'tracesid',   app.TraceSid, ...
                'condfile',   app.CondFileName, ...
                'baseline',   app.Baseline, ...
                'fitapplied', app.FitApplied, ...
                'outdir',     app.OutDirField.Value, ...
                'basename',   app.BaseNameField.Value, ...
                'bandthk',    app.BandThkF.Value, ...
                'bandcuts',   app.bandCuts(), ...
                'bandclips',  app.bandClips(), ...
                'planesets',  app.PlaneSets, ...
                'planes',     {app.PlanesLocal}, ...
                'planessid',  app.PlanesSid, ...
                'planesfile', app.PlanesFileName, ...
                'planesfmt',  app.PlanesFmt, ...
                'sizelaw',    app.sizeLaw(), ...
                'aspect',     app.AspectField.Value, ...
                'aspectsd',   app.AspectSdField.Value, ...
                'aspectlaw',  app.AspectLawDD.Value, ...
                'longaxis',   app.AxisDD.Value, ...
                'intensity',  app.intensityMode(), ...
                'orientation', app.orientModel(), ...
                'centres',    app.centresModel(), ...
                'cluster',    app.ClusterField.Value, ...
                'terminate',  app.TermField.Value);
        end

        function applyUIState(app, u)
            %APPLYUISTATE  Put back whatever uiState recorded.
            %   Field by field and never fatally: a session is a file that can
            %   be carried between versions of the app and edited by hand, so
            %   one value it no longer has -- or one it has that a control will
            %   not accept -- must not stop the rest of the session loading.
            if ~isstruct(u), return, end
            app.setIf(app.ShapeDD,     'Value', u, 'shape');
            app.setIf(app.FacetSpin,   'Value', u, 'facets');
            app.setIf(app.ASepField,   'Value', u, 'asep');
            app.setIf(app.DSepField,   'Value', u, 'dsep');
            app.setIf(app.SecDipF,     'Value', u, 'secdip');
            app.setIf(app.SecDirF,     'Value', u, 'secdir');
            app.setIf(app.SecOffF,     'Value', u, 'secoff');
            app.setIf(app.SecClipDD,   'Value', u, 'clip');
            app.setIf(app.CondSrcDD,   'Value', u, 'condsrc');
            if isfield(u,'condtab') && any(size(u.condtab,2) == [6 7]), app.TraceSets = app.padTraceSets(u.condtab); end
            app.setIf(app.CondCB,      'Value', u, 'condon');
            app.setIf(app.CondExclCB,  'Value', u, 'condexcl');
            app.setIf(app.OutDirField, 'Value', u, 'outdir');
            app.setIf(app.BaseNameField,'Value',u, 'basename');
            if isfield(u,'tracemap'),   app.TraceMap     = u.tracemap;   end
            if isfield(u,'tracesid'),   app.TraceSid     = u.tracesid;   end
            if isfield(u,'condfile'),   app.CondFileName = u.condfile;   end
            if isfield(u,'baseline') && isstruct(u.baseline)
                app.Baseline = u.baseline;
            end
            if isfield(u,'fitapplied'), app.FitApplied   = logical(u.fitapplied); end
            app.setIf(app.BandThkF, 'Value', u, 'bandthk');
            app.setIf(app.BandCutCB, 'Value', u, 'bandcuts');
            app.setIf(app.BandClipCB, 'Value', u, 'bandclips');
            if isfield(u,'planesets') && any(size(u.planesets,2) == [8 9])
                app.PlaneSets = app.padSets(u.planesets);
            end
            app.setIf(app.SizeLawDD, 'Value', u, 'sizelaw');
            app.onSizeLawChanged();
            app.setIf(app.AspectField,   'Value', u, 'aspect');
            app.setIf(app.AspectSdField, 'Value', u, 'aspectsd');
            app.setIf(app.AspectLawDD,   'Value', u, 'aspectlaw');
            app.setIf(app.AxisDD,        'Value', u, 'longaxis');
            app.setIf(app.IntensityDD,   'Value', u, 'intensity');
            app.LastIntensity = app.intensityMode();
            app.setIf(app.OrientDD,      'Value', u, 'orientation');
            app.LastOrient = app.orientModel();
            app.setIf(app.CentresDD,     'Value', u, 'centres');
            app.setIf(app.ClusterField,  'Value', u, 'cluster');
            app.setIf(app.TermField,     'Value', u, 'terminate');
            app.applyModeToTable();
            app.refreshEngineUI();
            if isfield(u,'planes') && iscell(u.planes), app.PlanesLocal = u.planes(:); end
            if isfield(u,'planessid'), app.PlanesSid = u.planessid(:); end
            if isfield(u,'planesfile'), app.PlanesFileName = u.planesfile; end
            if isfield(u,'planesfmt'),  app.PlanesFmt = u.planesfmt; end
            app.refreshCondUI();
            app.refreshRestoreBtn();
            app.describeSection();
        end

        function setIf(~, h, prop, u, f)
            %SETIF  Restore one control from one session field, if it is there.
            if isempty(h) || ~isvalid(h) || ~isfield(u,f), return, end
            try, h.(prop) = u.(f); catch, end %#ok<CTCH>
        end

        function onLoadSession(app, target)
            %ONLOADSESSION  Read a session, asking which unless told.
            if nargin >= 2 && ~isempty(target)
                [pth, base, ext] = fileparts(target);
                if isempty(ext), ext = '.mat'; end
                fn = [base ext];
            else
                [fn, pth] = uigetfile('*.mat','Load session', app.OutDirField.Value);
                figure(app.Fig);
                if isequal(fn,0), return; end
            end
            fp = fullfile(pth,fn);
            % A file that is not there, or is there and unreadable, used to
            % throw out of the callback as a raw MATLAB error.
            if ~isfile(fp)
                uialert(app.Fig, sprintf(['There is no session file at' newline ...
                    '    %s'], fp), 'Load failed');
                return
            end
            try
                S = load(fp);
            catch ME
                uialert(app.Fig, sprintf(['That file could not be read as a ' ...
                    'MATLAB file:' newline newline '%s'], ME.message), 'Load failed');
                return
            end
            if ~isfield(S,'session'), uialert(app.Fig,'Not an ADFNE session file.','Load failed'); return; end
            s = S.session;
            % sessions written before the move to ADFNE 1.5 used three modes
            % ('3DP' polygons, '3DD' discs) and different set-table columns
            mode = s.mode;
            if any(strcmp(mode, {'3DP','3DD'})), mode = '3D'; end
            app.ModeDD.Value = mode;
            app.applyModeToTable();
            if isfield(s,'setstore') && size(s.setstore,2) == 10
                app.Sets = s.setstore;              % full canonical store
                app.applyModeToTable();
            elseif isempty(s.sets) || any(size(s.sets, 2) == [8 9])
                app.SetTable.Data = app.padSets(s.sets);   % 8 columns: before Lp
                app.harvestSets();
                app.applyModeToTable();
            else
                app.log(['Session was saved with different fracture-set columns; ' ...
                         'defaults kept. Re-enter the sets before generating.'],'warn');
            end
            for i = 1:6, app.RgnFields(i).Value = s.rgn(i); end
            app.SeedSpin.Value = s.seed;
            app.Model = s.model;
            if isfield(s,'vars'), app.Vars = s.vars; end
            % after Model, because refreshCondUI and describeSection both read it
            if isfield(s,'ui')
                app.applyUIState(s.ui);
            else
                app.log(['This session was saved by an older version, which did ' ...
                    'not record the fracture shape, the separation constraints ' ...
                    'or the section plane. Those controls keep their current ' ...
                    'values, so check them before generating again.'],'warn');
            end
            app.refreshAnalyses(); app.refreshResultsTable(); app.refreshEngineUI();
            app.refreshPlotTypes(); app.syncVars(); app.refreshStateBar();
            app.renderPlot();
            app.log(['Session loaded from ' fp],'ok');
        end
    end

    %% ------------------------------------------------------------ Library tab
    methods (Access = public, Hidden = true)

        function onSearch(app)
            q = lower(strtrim(app.SearchField.Value));
            if isempty(q)
                app.FcnList.Items = app.FcnNames;
            else
                k = contains(lower(app.FcnNames), q);
                it = app.FcnNames(k);
                if isempty(it), it = {'(no match)'}; end
                app.FcnList.Items = it;
            end
            if ~isempty(app.FcnList.Items)
                app.FcnList.Value = app.FcnList.Items{1};
                app.onFcnSelected();
            end
        end

        function onFcnSelected(app)
            nm = app.FcnList.Value;
            if isempty(nm) || startsWith(nm,'('), return; end
            app.HelpArea.Value = app.helpTextOf(nm);
        end

        function txt = helpTextOf(app, nm)
            % Read the leading comment block straight from the file. Works in
            % both MATLAB and the MATLAB Runtime, where help() is unavailable.
            txt = {'(no help text)'};
            ix = find(strcmp(app.FcnNames, nm), 1);
            if isempty(ix), return; end
            try
                L = splitlines(fileread(app.FcnFiles{ix}));
            catch
                return
            end
            out = {}; started = false;
            for i = 1:numel(L)
                t = strtrim(L{i});
                if ~started
                    if startsWith(t, 'function'), started = true; end
                    continue
                end
                if startsWith(t, '%')
                    line = regexprep(L{i}, '^\s*%\s?', '');
                    out{end+1} = line; %#ok<AGROW>
                elseif isempty(t)
                    if ~isempty(out), out{end+1} = ''; end %#ok<AGROW>
                else
                    break
                end
            end
            while ~isempty(out) && isempty(strtrim(out{end})), out(end) = []; end
            if ~isempty(out)
                if strcmpi(strtrim(out{1}), nm)      % ADFNE repeats the name
                    txt = out(:);
                else
                    txt = [{nm}; out(:)];
                end
            end
        end

        function onInsertTemplate(app)
            nm = app.FcnList.Value;
            if isempty(nm) || startsWith(nm,'('), return; end
            [outs, ins] = app.signatureOf(nm);
            if isempty(outs), lhs = '';
            elseif numel(outs) == 1, lhs = [outs{1} ' = '];
            else, lhs = ['[' strjoin(outs,', ') '] = ']; end
            app.ConsoleArea.Value = {sprintf('%s%s(%s)', lhs, nm, strjoin(ins, ', '))};
        end

        function [outs, ins] = signatureOf(app, nm)
            outs = {}; ins = {};
            ix = find(strcmp(app.FcnNames, nm), 1);
            if isempty(ix), return; end
            try
                txt = fileread(app.FcnFiles{ix});
            catch, return; end
            L = regexp(txt, '\r?\n', 'split');
            for i = 1:min(numel(L), 40)
                s = strtrim(L{i});
                if startsWith(s, 'function')
                    s = strtrim(extractAfter(s,'function'));
                    eq = strfind(s,'=');
                    if ~isempty(eq)
                        o = s(1:eq(1)-1);
                        o = strrep(strrep(o,'[',''),']','');
                        outs = strtrim(strsplit(o,','));
                        s = s(eq(1)+1:end);
                    end
                    p = regexp(s,'\(([^)]*)\)','tokens','once');
                    if ~isempty(p) && ~isempty(strtrim(p{1}))
                        ins = strtrim(strsplit(p{1},','));
                    end
                    outs = outs(~cellfun(@isempty,outs));
                    ins  = ins(~cellfun(@isempty,ins));
                    return
                end
            end
        end

        function onEvaluate(app)
            expr__ = strjoin(cellstr(app.ConsoleArea.Value), newline);
            if isempty(strtrim(expr__)), return; end
            vars__  = app.Vars;
            names__ = fieldnames(vars__);
            for i__ = 1:numel(names__)
                eval([names__{i__} ' = vars__.(names__{i__});']);
            end
            try
                out__ = evalc(expr__);
                if isempty(strtrim(out__)), out__ = '(evaluated, no display output)'; end
                app.OutArea.Value = splitlines(strtrim(out__));
                app.log(['>> ' strrep(expr__, newline, ' ; ')],'ok');
            catch ME__
                app.OutArea.Value = [{['ERROR: ' ME__.message]}; {''}];
                app.log(['Console error: ' ME__.message],'error');
                return
            end
            % harvest resulting variables back into the store
            w__ = who;
            skip__ = {'expr__','vars__','names__','i__','out__','w__','skip__','app','ME__','k__','nm__'};
            new__ = struct();
            for k__ = 1:numel(w__)
                nm__ = w__{k__};
                if any(strcmp(nm__, skip__)), continue; end
                new__.(nm__) = eval(nm__);
            end
            app.Vars = new__;
            app.refreshVarTable();
        end

        function onPlotVar(app)
            d = app.VarTable.Data;
            if isempty(d), return; end
            sel = [];
            try, sel = app.VarTable.Selection; catch, end
            if isempty(sel), r = 1; else, r = sel(1); end
            nm = d{r,1};
            v = app.Vars.(nm);
            try
                if iscell(v) && ~isempty(v) && isnumeric(v{1}) && size(v{1},2) == 3
                    app.renderVia(@() DrawPolys3D(v, [], [0.2 0.42 0.68 app.AlphaSld.Value], true), true);
                elseif isnumeric(v) && size(v,2) == 4 && size(v,1) > 1
                    app.renderVia(@() DrawLines2D(v, [], [0 0 0], '=['), false);
                elseif isnumeric(v) && ismatrix(v) && min(size(v)) > 1
                    app.renderVia(@() localImg(v), false);
                elseif isnumeric(v) && isvector(v)
                    app.renderVia(@() localVec(v), false);
                else
                    app.log(sprintf('Do not know how to plot "%s" (%s).', nm, class(v)),'warn');
                    return
                end
                app.setStatus(['plotted variable: ' nm]);
                app.log(['Plotted variable ' nm],'ok');
            catch ME
                app.log(['Plot variable failed: ' ME.message],'error');
            end
            function localImg(M)
                imagesc(M); axis image; colorbar; set(gca,'YDir','normal'); title(nm,'Interpreter','none');
            end
            function localVec(V)
                if numel(V) > 40, histogram(V,30); title([nm ' (histogram)'],'Interpreter','none');
                else, bar(V); title(nm,'Interpreter','none'); end
                grid on
            end
        end

        function onToWorkspace(app)
            f = fieldnames(app.Vars);
            for i = 1:numel(f)
                assignin('base', f{i}, app.Vars.(f{i}));
            end
            app.log(sprintf('Exported %d variables to the base workspace.', numel(f)),'ok');
        end

        function syncVars(app)
            if isempty(app.VarTable) || ~isvalid(app.VarTable), return, end
            m = app.Model;
            V = app.Vars;
            V.fnm = m.fnm;              % the 3D fractures, always
            V.rgn = m.rgn;
            % the traces on the section plane, so console work in the 2D view
            % has the same data the 2D tabs operate on
            if isfield(m,'sec') && ~isempty(m.sec) && isfield(m.sec,'lines')
                V.traces = m.sec.lines;
            end
            if ~isempty(m.La), V.La = m.La; end
            if isfield(m,'setid'), V.setid = m.setid; end
            R = m.results; f = fieldnames(R);
            for i = 1:numel(f), V.(f{i}) = R.(f{i}); end
            app.Vars = V;
            app.refreshVarTable();
        end

        function refreshVarTable(app)
            if isempty(app.VarTable) || ~isvalid(app.VarTable), return, end
            f = sort(fieldnames(app.Vars));
            d = cell(numel(f),3);
            for i = 1:numel(f)
                v = app.Vars.(f{i});
                d(i,:) = {f{i}, class(v), char(mat2str(size(v)))};
            end
            app.VarTable.Data = d;
        end
    end

    %% -------------------------------------------------------------- utilities
    methods (Access = public, Hidden = true)

        function toggleLog(app)
            app.setLogExpanded(~app.LogExpanded);
        end

        function setLogExpanded(app, expanded)
            if isempty(app.LogGrid) || ~isvalid(app.LogGrid), return, end
            app.LogExpanded = logical(expanded);
            rh = app.RootGrid.RowHeight;
            if app.LogExpanded
                rh{4} = 132;
                app.LogGrid.RowHeight = {26,'1x'};
                app.LogArea.Visible = 'on';
                app.LogToggleBtn.Text = 'Log  v';
            else
                rh{4} = 26;
                app.LogGrid.RowHeight = {26,0};
                app.LogArea.Visible = 'off';
                app.LogToggleBtn.Text = 'Log  ^';
            end
            app.RootGrid.RowHeight = rh;
        end

        function showFocusHelp(app, obj)
            %SHOWFOCUSHELP  Surface the existing expert tooltip in the strip.
            % Mouse focus arrives through hittest; keyboard focus through the
            % figure's CurrentObject. An active error keeps priority until a
            % later log entry clears it.
            if app.LogErrorActive || isempty(obj) || ~isvalid(obj), return, end
            for depth = 1:12
                if isprop(obj,'Tooltip')
                    tip = strjoin(string(obj.Tooltip),' ');
                    tip = regexprep(strtrim(tip),'\s+',' ');
                    if strlength(tip) > 0
                        app.LogSummary.Text = char(tip);
                        app.LogSummary.FontColor = [0.25 0.29 0.34];
                        app.LogGrid.BackgroundColor = app.BG;
                        return
                    end
                end
                if isequal(obj,app.Fig) || ~isprop(obj,'Parent') || isempty(obj.Parent)
                    break
                end
                obj = obj.Parent;
            end
            if ~isempty(app.LastLogLine), app.LogSummary.Text = app.LastLogLine; end
        end

        function log(app, msg, kind)
            if nargin < 3, kind = 'info'; end
            switch kind
                case 'ok',    p = '[ok]   ';
                case 'error', p = '[ERROR] ';
                case 'warn',  p = '[warn] ';
                otherwise,    p = '[info] ';
            end
            ts = char(datetime('now','Format','HH:mm:ss'));
            line = sprintf('%s %s%s', ts, p, msg);
            v = app.LogArea.Value;
            if ischar(v), v = {v}; end
            v = v(~cellfun(@isempty, v));
            % newest first: the latest entry is always visible without
            % scrolling (scroll(uitextarea,'bottom') blanks the control).
            v = [{line}; v(:)];
            if numel(v) > 500, v = v(1:500); end
            app.LogArea.Value = v;
            app.LastLogLine = line;
            app.LogSummary.Text = line;
            app.LogErrorActive = strcmp(kind,'error');
            switch kind
                case 'error'
                    app.LogSummary.FontColor = app.ERR_COL;
                    app.LogGrid.BackgroundColor = [1.000 0.925 0.925];
                    app.setLogExpanded(true);
                case 'warn'
                    app.LogSummary.FontColor = app.WARN_COL;
                    app.LogGrid.BackgroundColor = [1.000 0.970 0.900];
                otherwise
                    app.LogSummary.FontColor = [0.30 0.34 0.38];
                    app.LogGrid.BackgroundColor = app.BG;
            end
            drawnow limitrate
        end

        function cl = busy(app, msg, heavy, key)
            %BUSY  Feedback while something slow runs.
            %   Returns an onCleanup, so the caller writes
            %       c = app.busy('rendering...', true);   %#ok<NASGU>
            %   and everything is put back however the function exits.
            %
            %   heavy asks for a modal dialog, which also blocks the repeated
            %   clicking that piles more work on an already busy app. Only the
            %   outermost busy() raises one: generate calls render, and two
            %   stacked modal dialogs are worse than none.
            %
            %   heavy = 'auto' decides from how long this same kind of work
            %   took last time. Rendering used to decide on fracture count,
            %   which stopped meaning anything the moment the patches were
            %   batched: cost went flat, so a 2150-fracture model rendered in
            %   0.53 s and got the dialog while a 430-fracture one took 0.71 s
            %   and did not. Time is the thing worth measuring, so measure it.
            if nargin < 3, heavy = false; end
            if nargin < 4, key = ''; end
            app.setStatus(msg, true);
            old = 'arrow';
            try, old = app.Fig.Pointer; app.Fig.Pointer = 'watch'; catch, end
            if ischar(heavy) || isstring(heavy)
                show = app.opWasSlow(key);      % 'auto'
            else
                show = logical(heavy);
            end
            dlg = [];
            if show && app.BusyDepth == 0
                try
                    dlg = uiprogressdlg(app.Fig, 'Title','Working', ...
                        'Message', msg, 'Indeterminate','on');
                catch, dlg = []; end
            end
            app.BusyDepth = app.BusyDepth + 1;
            % tic BEFORE the lambda: written inside it, it would be evaluated
            % when the cleanup runs and every operation would measure zero
            t0 = tic;
            cl = onCleanup(@() app.unbusy(old, dlg, key, t0));
        end

        function unbusy(app, oldPointer, dlg, key, t0)
            app.BusyDepth = max(0, app.BusyDepth - 1);
            if ~isempty(dlg) && isvalid(dlg), close(dlg); end
            try, app.Fig.Pointer = oldPointer; catch, end
            if nargin >= 5 && ~isempty(key)
                app.OpTimes.(app.opKey(key)) = toc(t0);
            end
            if app.BusyDepth == 0, app.setStatus('ready'); end
        end

        function tf = opWasSlow(app, key)
            %OPWASSLOW  Did this kind of work take long enough to warrant a
            %   modal dialog? 1.2 s: below that the wait cursor and the status
            %   line carry it, and a dialog flashing on every slider nudge
            %   would be worse than none. The first run of a kind cannot know,
            %   so it goes without and the next one is informed.
            tf = false;
            if isempty(key), return, end
            f = app.opKey(key);
            if isfield(app.OpTimes, f), tf = app.OpTimes.(f) > 1.2; end
        end

        function f = opKey(~, key)
            f = matlab.lang.makeValidName(char(key));
        end

        function setStatus(app, s, working)
            %SETSTATUS  The status line, which is the feedback you get for
            %   work too short to deserve a dialog. It has to be readable at a
            %   glance, so it changes colour and weight while something runs.
            if nargin < 3, working = false; end
            app.StatusLbl.Text = s;
            if working
                app.StatusLbl.FontColor = app.ACCENT;
                app.StatusLbl.FontWeight = 'bold';
            else
                app.StatusLbl.FontColor = [0.35 0.35 0.35];
                app.StatusLbl.FontWeight = 'normal';
            end
            drawnow limitrate
        end
    end

    %% ------------------------------------------------------------- help mode
    % The help is the workbench itself. ADFNE_GUI(root, 'help') builds the
    % normal window, then: every callback is rerouted to helpOn, every
    % control is enabled so it can be clicked, and the viewport becomes a
    % page that explains whatever was clicked - a tab, a button, a field, a
    % table column, a dropdown item. Because the help window is built by the
    % same constructor as the working one, a control added to the app is in
    % the help the moment it exists, and its tooltip - which the test suite
    % requires of every control - is its explanation. helpTopics adds the
    % why and the when on top of the tooltip's what.
    methods (Access = public, Hidden = true)
        function openHelp(app)
            %OPENHELP  The help window: this window again, explaining itself.
            if ~isempty(app.HelpApp) && isvalid(app.HelpApp) && ...
                    ~isempty(app.HelpApp.Fig) && isvalid(app.HelpApp.Fig)
                figure(app.HelpApp.Fig); return
            end
            app.setStatus('opening the help window…', true);
            try
                app.HelpApp = ADFNE_GUI(app.AdfneRoot, 'help');
            catch ME
                app.setStatus('ready', false);
                rethrow(ME);
            end
            app.setStatus('ready', false);
        end

        function enterHelpMode(app)
            %ENTERHELPMODE  Turn this window into the help.
            app.Fig.Name = sprintf('ADFNE Workbench %s  -  HELP   (nothing here changes a model)', app.VERSION);
            app.Fig.Tag  = 'ADFNE_GUI_help';
            app.applyHelpSkin();
            app.PlotHost.Title = 'Help  -  click any control to read about it';
            app.PlotHost.ForegroundColor = app.ACCENT;
            if ~isempty(app.Ax) && isvalid(app.Ax), delete(app.Ax); end
            app.HelpHtml = uihtml(app.PlotGrid);
            app.registerHelpHandles();
            hs = findall(app.Fig);
            if ~isempty(app.ExportFig) && isvalid(app.ExportFig), hs = [hs; findall(app.ExportFig)]; end
            app.rerouteForHelp(hs);
            app.TabGroup.SelectionChangedFcn = @(s,e) app.helpOn(e.NewValue, e);
            app.Fig.WindowKeyReleaseFcn = @(s,e) app.helpOn(s.CurrentObject, []);
            app.DockToggleBtn.ButtonPushedFcn = @(s,e) app.helpAnd(s, e, @() app.toggleDock());
            app.LogToggleBtn.ButtonPushedFcn  = @(s,e) app.helpAnd(s, e, @() app.toggleLog());
            app.setDockExpanded(false);
            app.StateFactsLbl.Text = ['HELP MODE  |  Every control here can be clicked, even the ones the ' ...
                'working window greys out until their turn - and none of them builds anything.'];
            app.StateFactsLbl.FontColor = app.ACCENT;
            app.LogSummary.Text = 'Help  |  click any control, tab, table column or dropdown item';
            app.showHelpPage(app.helpWelcome());
        end

        function applyHelpSkin(app)
            %APPLYHELPSKIN  The help window in its own colour, so it is never
            %   mistaken for the working one. Only the neutrals move: the
            %   window itself, every panel background and the state bar are
            %   remapped to their warm twins; the accent and the register
            %   tints are left exactly as they are, because they mean
            %   something and the help must teach the same colours the
            %   working window uses.
            app.Fig.Color = app.HELP_BG;
            hs = findall(app.Fig);
            if ~isempty(app.ExportFig) && isvalid(app.ExportFig)
                app.ExportFig.Color = app.HELP_BG;
                hs = [hs; findall(app.ExportFig)];
            end
            was = {app.BG, app.PANEL, [0.925 0.935 0.945]};
            now = {app.HELP_BG, app.HELP_PANEL, app.HELP_BAR};
            for i = 1:numel(hs)
                h = hs(i);
                if ~isvalid(h) || ~isprop(h, 'BackgroundColor'), continue, end
                try, c = h.BackgroundColor; catch, continue, end %#ok<CTCH>
                if ~isnumeric(c) || numel(c) ~= 3, continue, end
                for k = 1:numel(was)
                    if max(abs(c - was{k})) < 1e-6
                        try, h.BackgroundColor = now{k}; catch, end %#ok<CTCH>
                        break
                    end
                end
            end
        end

        function registerHelpHandles(app)
            %REGISTERHELPHANDLES  Every control the app holds in a property,
            %   by name, so a click can be named after the property.
            mc = metaclass(app); pl = mc.PropertyList;
            nm = {}; hs = gobjects(0);
            for i = 1:numel(pl)
                if pl(i).Constant || ~strcmp(pl(i).GetAccess, 'public'), continue, end
                try, v = app.(pl(i).Name); catch, continue, end %#ok<CTCH>
                if isempty(v) || iscell(v) || isstruct(v) || isnumeric(v) || ischar(v) || islogical(v), continue, end
                try, ok = all(isgraphics(v(:))); catch, ok = false; end %#ok<CTCH>
                if ~ok, continue, end
                if isscalar(v)
                    nm{end+1} = pl(i).Name; hs(end+1) = v; %#ok<AGROW>
                else
                    for k = 1:numel(v)
                        nm{end+1} = sprintf('%s(%d)', pl(i).Name, k); hs(end+1) = v(k); %#ok<AGROW>
                    end
                end
            end
            app.HelpNames = nm; app.HelpHandles = hs;
        end

        function rerouteForHelp(app, hs)
            %REROUTEFORHELP  Every callback explains; every control is live.
            cbs = {'ButtonPushedFcn','ValueChangedFcn','SelectionChangedFcn', ...
                   'CellSelectionCallback','CellEditCallback','ImageClickedFcn', ...
                   'ClickedFcn','DoubleClickedFcn'};
            for i = 1:numel(hs)
                h = hs(i);
                if ~isvalid(h) || isequal(h, app.Fig) || isequal(h, app.TabGroup) || ...
                        isa(h, 'matlab.ui.container.Tab') || isa(h, 'matlab.ui.control.HTML')
                    continue
                end
                for c = cbs
                    if isprop(h, c{1})
                        try, h.(c{1}) = @(s,e) app.helpOn(s, e); catch, end %#ok<CTCH>
                    end
                end
                if isprop(h, 'Enable'), try, h.Enable = 'on'; catch, end, end %#ok<CTCH>
            end
        end

        function helpOn(app, s, e)
            %HELPON  A control was clicked in the help: explain it, and put
            %   back whatever the click changed on it.
            if ~app.HelpMode || isempty(s) || ~isvalid(s), return, end
            if isequal(s, app.HelpHtml) || isequal(s, app.Fig), return, end
            pick = [];
            has = @(o, f) ~isempty(o) && ((isstruct(o) && isfield(o, f)) || (isobject(o) && isprop(o, f)));
            if has(e, 'Value'), pick = e.Value; end
            try
                if isa(s, 'matlab.ui.control.StateButton')
                    s.Value = false;
                elseif has(e, 'PreviousData') && isa(s, 'matlab.ui.control.Table')
                    s.Data(e.Indices(1), e.Indices(2)) = e.PreviousData;
                elseif has(e, 'PreviousValue') && isprop(s, 'Value')
                    s.Value = e.PreviousValue;
                end
            catch, end %#ok<CTCH>
            app.showHelpPage(app.helpPageFor(s, e, pick));
        end

        function helpAnd(app, s, e, action)
            %HELPAND  The two toggles that must still work in the help - the
            %   display dock and the log - so their contents can be reached:
            %   do the thing, then explain it.
            try, action(); catch, end %#ok<CTCH>
            app.helpOn(s, e);
        end

        function showHelpPage(app, html)
            if isempty(app.HelpHtml) || ~isvalid(app.HelpHtml), return, end
            app.HelpHtml.HTMLSource = html;
        end

        function [key, name, kind] = helpIdentity(app, h)
            %HELPIDENTITY  Registry key, display name and kind of a control.
            key = ''; name = ''; kind = '';
            try
                k = find(app.HelpHandles == h, 1);
                if ~isempty(k), key = app.HelpNames{k}; end
            catch, end %#ok<CTCH>
            cls = strsplit(class(h), '.'); cls = cls{end};
            words = struct('Button','button', 'StateButton','toggle button', 'DropDown','dropdown', ...
                'CheckBox','checkbox', 'NumericEditField','field', 'EditField','text field', ...
                'Spinner','spinner', 'Table','table', 'Tab','tab', 'ListBox','list', ...
                'Slider','slider', 'Label','label', 'Panel','panel', 'TextArea','text area', ...
                'Tree','tree', 'Image','image');
            if isfield(words, cls), kind = words.(cls); else, kind = lower(cls); end
            txt = '';
            if isprop(h, 'Text') && (ischar(h.Text) || isstring(h.Text)), txt = char(strjoin(string(h.Text), ' ')); end
            if isempty(txt) && isprop(h, 'Title'), txt = char(h.Title); end
            txt = regexprep(strtrim(txt), '\s+·\s+.*$', '');
            if isempty(key)
                if isa(h, 'matlab.ui.container.Tab'), key = ['tab:' txt];
                elseif ~isempty(txt),                  key = ['text:' txt];
                end
            end
            N = app.helpNames();
            base = regexprep(key, '\(\d+\)$', '');
            if N.isKey(base),  name = N(base);
            elseif ~isempty(txt), name = txt;
            elseif ~isempty(key), name = key;
            else, name = kind;
            end
            if startsWith(key, 'RgnFields(')
                lbl = {'X min','X max','Y min','Y max','Z min','Z max'};
                k = sscanf(key, 'RgnFields(%d)'); if ~isempty(k) && k <= 6, name = ['Domain ' lbl{k}]; end
            end
        end

        function loc = helpLocation(app, h)
            %HELPLOCATION  Where the control lives: tab › panel › ...
            parts = {}; o = h;
            for depth = 1:14
                if ~isprop(o, 'Parent') || isempty(o.Parent), break, end
                o = o.Parent;
                if isequal(o, app.Fig), break, end
                t = '';
                if isequal(o, app.StateBar),                       t = 'State bar';
                elseif ~isempty(app.ViewGrid) && isequal(o, app.ViewGrid),  t = 'Viewport';
                elseif ~isempty(app.DockBody) && isequal(o, app.DockBody),  t = 'Display dock';
                elseif ~isempty(app.LogGrid) && isequal(o, app.LogGrid),    t = 'Log strip';
                elseif ~isempty(app.ExportFig) && isequal(o, app.ExportFig), t = 'Export window';
                elseif isa(o, 'matlab.ui.container.Panel') && isequal(o.BackgroundColor, app.ACCENT), t = 'Header';
                elseif isa(o, 'matlab.ui.container.Tab') || isa(o, 'matlab.ui.container.Panel')
                    t = regexprep(char(o.Title), '\s+·\s+.*$', '');
                    if isa(o, 'matlab.ui.container.Tab'), t = [t ' tab']; end
                end
                if ~isempty(t), parts{end+1} = t; end %#ok<AGROW>
            end
            loc = strjoin(fliplr(parts), '  ›  ');
        end

        function lbl = helpItemLabel(~, h, it)
            %HELPITEMLABEL  The visible name of a dropdown or list item.
            lbl = char(string(it));
            try
                if isprop(h, 'ItemsData') && ~isempty(h.ItemsData)
                    for k = 1:numel(h.ItemsData)
                        if isequal(h.ItemsData{k}, it), lbl = h.Items{k}; return, end
                    end
                end
            catch, end %#ok<CTCH>
        end

        function html = helpPageFor(app, h, e, pick)
            %HELPPAGEFOR  The page for one control.
            [key, name, kind] = app.helpIdentity(h);
            T = app.helpTopics();
            esc = @(t) app.htmlEscape(t);
            parts = {};
            parts{end+1} = sprintf('<div class="crumb">%s</div>', esc(app.helpLocation(h)));
            parts{end+1} = sprintf('<h1>%s <span class="kind">%s</span></h1>', esc(name), esc(kind));
            sub = '';
            if isa(h, 'matlab.ui.control.DropDown') && ~isempty(pick)
                it = pick; if iscell(it), it = it{end}; end
                parts{end+1} = sprintf('<div class="pick">You chose:&nbsp; <b>%s</b></div>', esc(app.helpItemLabel(h, it)));
                sub = sprintf('%s:%s', key, char(string(it)));
            elseif isa(h, 'matlab.ui.control.ListBox') && ~isempty(pick)
                it = pick; if iscell(it), if isempty(it), it = ''; else, it = it{end}; end, end
                if ~isempty(it)
                    parts{end+1} = sprintf('<div class="pick">You chose:&nbsp; <b>%s</b></div>', esc(app.helpItemLabel(h, it)));
                    sub = sprintf('%s:%s', key, strtrim(regexprep(char(string(it)), '\s*\|.*$', '')));
                end
            elseif isa(h, 'matlab.ui.control.Table') && ~isempty(e) && ...
                    ((isstruct(e) && isfield(e, 'Indices')) || (isobject(e) && isprop(e, 'Indices'))) && ~isempty(e.Indices)
                col = e.Indices(1, 2); cn = string(h.ColumnName);
                if col <= numel(cn)
                    parts{end+1} = sprintf('<div class="pick">Column:&nbsp; <b>%s</b></div>', esc(cn(col)));
                    sub = sprintf('%s:col:%s', key, char(cn(col)));
                    if ~T.isKey(sub) && strcmp(key, 'CondTable') && numel(cn) == 9
                        sub = sprintf('SetTable:col:%s', char(cn(col)));   % the 3D table shares the set columns
                    end
                end
            end
            if isa(h, 'matlab.ui.container.Tab'), key = ['tab:' regexprep(char(h.Title), '\s+·\s+.*$', '')]; end
            if T.isKey(sub), parts{end+1} = ['<div class="topic">' T(sub) '</div>']; end
            base = regexprep(key, '\(\d+\)$', '');
            if T.isKey(key),      parts{end+1} = ['<div class="topic">' T(key) '</div>'];
            elseif T.isKey(base), parts{end+1} = ['<div class="topic">' T(base) '</div>'];
            end
            tip = '';
            if isprop(h, 'Tooltip'), tip = char(strjoin(string(h.Tooltip), newline)); end
            if ~isempty(strtrim(tip))
                parts{end+1} = '<h2>In detail</h2>';
                parts{end+1} = app.tipToHtml(tip);
            elseif ~T.isKey(key) && ~T.isKey(base) && ~T.isKey(sub)
                parts{end+1} = '<p class="muted">Nothing more to say about this one: it is what it says.</p>';
            end
            parts{end+1} = '<p class="foot">Click another control, or a tab, to read about it.</p>';
            html = app.helpWrap(strjoin(parts, newline));
        end

        function t = htmlEscape(~, t)
            t = char(string(t));
            t = strrep(t, '&', '&amp;'); t = strrep(t, '<', '&lt;'); t = strrep(t, '>', '&gt;');
        end

        function html = tipToHtml(app, tip)
            %TIPTOHTML  A tooltip as HTML: aligned layouts keep their columns.
            tip = app.htmlEscape(tip);
            lines = strsplit(tip, newline);
            aligned = any(~cellfun(@isempty, regexp(lines, '\S\s{3,}\S', 'once')));
            if aligned
                html = sprintf('<pre>%s</pre>', tip);
            else
                paras = strsplit(tip, [newline newline]);
                paras = cellfun(@(q) sprintf('<p>%s</p>', strrep(strtrim(q), newline, ' ')), paras, 'UniformOutput', false);
                html = strjoin(paras, newline);
            end
        end

        function html = helpWrap(app, body)
            c = app.ACCENT;
            css = sprintf(['<style>' ...
                'body{font-family:"Segoe UI",Arial,sans-serif;font-size:13.5px;line-height:1.5;color:#222;' ...
                'margin:0;padding:14px 22px 22px 22px;background:#fffcf4;max-width:980px}' ...
                'h1{font-size:21px;margin:2px 0 8px 0;color:#1b2838}' ...
                'h1 .kind{font-size:12px;font-weight:normal;color:#777;margin-left:8px;text-transform:uppercase;letter-spacing:.06em}' ...
                'h2{font-size:12.5px;text-transform:uppercase;letter-spacing:.08em;color:#666;margin:18px 0 4px 0;' ...
                'border-bottom:1px solid #e3e6ea;padding-bottom:3px}' ...
                'h3{font-size:14px;margin:14px 0 4px 0;color:#1b2838}' ...
                '.crumb{font-size:11.5px;color:#888;letter-spacing:.03em}' ...
                '.pick{margin:0 0 10px 0;padding:6px 10px;background:#efe4d1;border-left:3px solid rgb(%d,%d,%d);border-radius:3px}' ...
                '.topic p{margin:6px 0}' ...
                'pre{font-family:Consolas,"Courier New",monospace;font-size:12.5px;white-space:pre-wrap;' ...
                'background:#f7f0e3;border:1px solid #e4dac6;border-radius:4px;padding:10px 12px;margin:6px 0}' ...
                'ul{margin:4px 0 8px 0;padding-left:22px} li{margin:2px 0}' ...
                'table.h{border-collapse:collapse;margin:6px 0} table.h td,table.h th{border:1px solid #dfe3e8;padding:3px 9px;text-align:left;vertical-align:top}' ...
                'table.h th{background:#f1f4f7}' ...
                'code{font-family:Consolas,monospace;background:#f3f4f6;padding:0 3px;border-radius:2px}' ...
                '.muted{color:#888} .foot{color:#999;font-size:12px;margin-top:22px}' ...
                '.step{margin:6px 0 6px 0;padding-left:10px;border-left:3px solid rgb(%d,%d,%d)}' ...
                '</style>'], round(255*c(1)), round(255*c(2)), round(255*c(3)), ...
                round(255*c(1)), round(255*c(2)), round(255*c(3)));
            html = ['<!DOCTYPE html><html><head><meta charset="utf-8">' css '</head><body>' body '</body></html>'];
        end

        function html = helpWelcome(app)
            %HELPWELCOME  The first page: what this window is and the workflow.
            body = [ ...
                '<div class="crumb">ADFNE Workbench ' app.VERSION '</div>' ...
                '<h1>Help <span class="kind">the workbench, explaining itself</span></h1>' ...
                '<p>This window is the workbench with one difference: <b>clicking anything explains it here instead of doing it</b>. ' ...
                'Click a tab to read what it is for, a button to read what it would do, a field or a dropdown item to read what it means, ' ...
                'a table column to read what goes in it. Every control is live to click, even those the working window greys out until their turn. ' ...
                'Nothing you do here touches your model; close this window when you are done.</p>' ...
                '<h2>The idea</h2>' ...
                '<p>ADFNE Workbench builds a three-dimensional <b>discrete fracture network</b> (DFN) - a stochastic model of the joints in a block of rock - ' ...
                'with the ADFNE library, and lets you fit that model to what you mapped, look at it, measure it and run flow through it. ' ...
                'The window is four tabs on the left, each a question about the rock mass, and a viewport on the right that shows the answer.</p>' ...
                '<h2>The workflow</h2>' ...
                '<div class="step"><b>1. Model tab - what the rock mass is.</b> Set the domain (the block, in your units), the section plane (where the 2D view cuts it), ' ...
                'one row per joint set in the table (count or intensity, orientation and its scatter, size and its law), and the options (shape, size law, orientation model, ' ...
                'centres, termination, seed). Press <b>GENERATE</b>.</div>' ...
                '<div class="step"><b>2. Conditioning tab - what the field said.</b> Import a trace map from a mapped face, or joint planes from a scan of a band, or author either ' ...
                'from statistics. Then either <b>FIT</b> (infer the joint-set parameters that reproduce the data, written back to the Model tab) or tick <b>condition</b> ' ...
                '(GENERATE builds the mapped features in exactly, with the stochastic network around them) - or both.</div>' ...
                '<div class="step"><b>3. Analysis tab - what can be measured.</b> Intersections and clusters, intensities, orientation and size statistics, connectivity, graph metrics, ' ...
                'density and connectivity fields on the section, variograms, boreholes. Results collect in a table and unlock plots.</div>' ...
                '<div class="step"><b>4. Flow tab - does it flow.</b> A pipe-network flow solve across the model between two faces, with the cubic law; hydraulic conductivity, ' ...
                'pressures and flow rates, plotted on the network.</div>' ...
                '<div class="step"><b>Export</b> the model or the picture (PNG, PDF, SVG, FIG, VTK, MAT, CSV), and <b>Save session</b> to pick everything up later.</div>' ...
                '<h2>Three registers</h2>' ...
                '<p>Every panel is tinted and tagged by what it is: <b>3D rock mass</b> (generative - part of what GENERATE builds from, so changing it makes the model out of date), ' ...
                '<b>viewing only</b> (how you look at the model; never regenerates), and <b>2D on the face</b> / <b>3D in a band</b> (measured field data, not the rock mass). ' ...
                'The state bar above the tabs says whether the picture matches every generative input (green) or GENERATE would build something else (amber).</p>' ...
                '<p class="foot">Start by clicking the Model tab.</p>'];
            html = app.helpWrap(body);
        end

        function N = helpNames(~)
            %HELPNAMES  Friendly names for the controls held in properties.
            N = containers.Map('KeyType', 'char', 'ValueType', 'char');
            kv = { ...
                'GenBtn', 'GENERATE'; 'HelpBtn', 'Help'; 'StateFactsLbl', 'State bar'; ...
                'RgnFields', 'Domain'; 'SetTable', 'Joint sets'; 'SeedSpin', 'Seed'; 'RandSeedCB', 'Randomise each run'; ...
                'FacetSpin', 'Facets'; 'SecDipF', 'Section plane dip'; 'SecDirF', 'Section plane dip direction'; ...
                'SecOffF', 'Section plane offset'; 'SecClipDD', 'Clip'; 'PresetDD', 'Preset'; 'SecShowCB', '3D Intersect'; ...
                'ShapeDD', 'Shape'; 'ASepField', 'asep'; 'DSepField', 'dsep'; 'SizeLawDD', 'Size law'; ...
                'AspectField', 'Aspect ratio'; 'AspectSdField', 'Aspect spread'; 'AxisDD', 'Long axis'; 'AspectLawDD', 'Aspect law'; ...
                'IntensityDD', 'Intensity measure'; 'OrientDD', 'Orientation model'; 'CentresDD', 'Centres'; 'TermField', 'Termination'; ...
                'CondCB', 'Condition the model on the field data'; 'CondSrcDD', 'Source'; 'CondTable', 'Synthetic statistics'; ...
                'CondSetDD', 'Set for the mapped features'; 'CondExclCB', 'Mapped face / band is complete'; 'CondFileLbl', 'Loaded file'; ...
                'CondInfo', 'Field-data info box'; 'CondPreviewBtn', 'Show traces / planes'; 'FitTable', 'Fit results'; ...
                'FitLbl', 'Fit heading'; 'CondCompareBtn', 'Compare'; 'CondRestoreBtn', 'Restore original DFN'; 'FitBtn', 'FIT'; ...
                'BandThkF', 'Band thickness'; 'BandCutCB', 'Planes cut the band (scan)'; 'BandClipCB', 'Planes clipped at the faces'; ...
                'AnaList', 'Available analyses'; 'AnaRunBtn', 'RUN SELECTED'; 'ResTable', 'Results'; 'AnaParamPanel', 'Analysis parameters'; ...
                'FlowDirDD', 'Flow direction'; 'FlowBCDD', 'Side boundaries'; 'FlowMtdDD', 'Pipe method'; 'FlowPinF', 'Inlet head'; ...
                'FlowPoutF', 'Outlet head'; 'FlowApF', 'Aperture'; 'FlowKvF', 'Kinematic viscosity'; 'FlowRunBtn', 'SOLVE FLOW'; ...
                'FlowInfo', 'Flow results'; 'GridSpin', 'Grid'; 'PlaneDD', 'Plane'; 'PlaneVal', 'Plane position'; ...
                'ModeDD', 'View'; 'PlotDD', 'Plot'; 'ColorDD', 'Colour'; 'AlphaSld', 'Opacity'; 'LWSpin', 'Line width'; ...
                'CmapDD', 'Colormap'; 'AzSld', 'Azimuth'; 'ElSld', 'Elevation'; 'RenderBtn', 'RENDER'; ...
                'DockToggleBtn', 'Display dock'; 'LogToggleBtn', 'Log'; 'LogArea', 'Activity log'; ...
                'OutDirField', 'Output folder'; 'BaseNameField', 'Base name'; 'FmtList', 'Formats'};
            for i = 1:size(kv, 1), N(kv{i, 1}) = kv{i, 2}; end
        end

        function T = helpTopics(~)
            %HELPTOPICS  The curated help: the why and the when, on top of
            %   the tooltip's what. Keys are property names, 'tab:<title>',
            %   'text:<button text>', '<prop>:<item>' for a dropdown or list
            %   item and '<prop>:col:<name>' for a table column.
            T = containers.Map('KeyType', 'char', 'ValueType', 'char');
            % ------------------------------------------------------- tabs
            T('tab:Model') = [ ...
                '<p><b>What the rock mass is.</b> Everything on this tab except the section plane is <i>generative</i>: it is what GENERATE builds the network from, ' ...
                'and changing any of it makes the current model out of date (the state bar turns amber).</p>' ...
                '<h3>Top to bottom</h3><ul>' ...
                '<li><b>Domain</b> - the block of rock, in your own units. Set it first: everything is generated inside it and clipped to it, intensity is measured per unit of it.</li>' ...
                '<li><b>Section plane</b> - where the 2D view cuts the model: dip, dip direction, offset from the domain centre, and presets. Viewing only.</li>' ...
                '<li><b>Joint sets</b> - one row per set: count or intensity, mean dip and dip direction with their scatter, size range and law. Add set / Remove set; the table may be empty while you import data.</li>' ...
                '<li><b>Options</b> - the shape of a fracture, the size law and its parameter, the orientation model, the intensity measure, how centres are placed, termination, the aspect ratio of elongated fractures, and the seed.</li></ul>' ...
                '<p>Then <b>GENERATE</b> (state bar). The joint-set table can also be filled by <b>FIT</b> on the Conditioning tab, from mapped data.</p>'];
            T('tab:Conditioning') = [ ...
                '<p><b>What the field said.</b> Field data and two independent things to do with it.</p>' ...
                '<div class="step"><b>1. The field data.</b> Choose a <b>Source</b>: a 2D trace map on the section face (imported <code>u1 v1 u2 v2 [set]</code>, or synthetic from trace statistics), ' ...
                'or 3D joint planes in a band (imported as centre + dip/dipdir + size, centre + normal + radius, polygon corners or a .mat; or synthetic from plane statistics). ' ...
                'For a band, say how thick it is and how the planes were recorded (centres in the band, every plane that cuts it, clipped at the faces). <b>Show</b> draws what FIT will read.</div>' ...
                '<div class="step"><b>2. FIT</b> - inversion. Infers the joint-set parameters that would produce this data and writes them to the Model tab: ' ...
                'from a trace map, size and intensity (orientation cannot be read from one face); from planes in a band, orientation, size and intensity, with the sampling and clipping corrections. ' ...
                'Restore puts the table back.</div>' ...
                '<div class="step"><b>3. Condition</b> - tick the box and GENERATE builds every mapped trace or plane in exactly, with the stochastic network around them. ' ...
                '<i>Mapped face / band is complete</i> rejects stochastic fractures that would add traces the map does not have.</div>' ...
                '<p><b>Compare</b> tests the generated model against the data: counts, intensities, size and orientation distributions, with the tests named.</p>'];
            T('tab:Analysis') = [ ...
                '<p><b>What can be measured on the model.</b> The list follows the View: in 3D, properties of the rock mass (intersections and clusters, intensities P10/P21/P32, ' ...
                'orientation and size statistics, centroids, boreholes); in 2D, what you can measure on the section (traces, isolated fractures, density and connectivity fields, ' ...
                'P21/P22, trace-length statistics). Each entry names the ADFNE function behind it. Select one or several, set their parameters in the panel, press RUN SELECTED; ' ...
                'results collect in the table and unlock the plots that draw them (Plot dropdown above the viewport).</p>'];
            T('tab:Flow') = [ ...
                '<p><b>Does it flow.</b> A steady-state flow solve through the fracture network as a network of pipes: each fracture intersection becomes a pipe, the cubic law gives ' ...
                'its conductance from the aperture, and a head difference is imposed between two opposite faces of the domain. Choose the direction, the side boundaries, the pipe method, ' ...
                'the inlet and outlet heads, the aperture and the fluid viscosity, then SOLVE FLOW. The result is the equivalent hydraulic conductivity of the block in that direction, ' ...
                'and the pressures and flow rates drawn on the network (Plot dropdown).</p>'];
            % ------------------------------------------------------- header
            T('GenBtn') = [ ...
                '<p><b>The one button that builds.</b> Takes the domain, the joint sets and the options and draws the network with the ADFNE generator: ' ...
                'orientations from the chosen model, sizes from the size law truncated to the row''s range, centres from the chosen placement, shapes, then clipping to the domain and termination. ' ...
                'With conditioning ticked, the mapped traces or planes go in first and the stochastic network is built around them.</p>' ...
                '<p>Greyed until the Model tab has what it needs. Every generative control makes it necessary again (amber state bar); viewing controls never do.</p>'];
            T('HelpBtn') = '<p>Opens this window.</p>';
            T('text:New') = '<p>Start again from the defaults. Save the session first if you may want any of it back.</p>';
            T('text:Export…') = [ ...
                '<p>Writes what you have to files, in a small window of its own: the picture (PNG, PDF, SVG, FIG), the model geometry (VTK for ParaView, MAT, CSV), ' ...
                'into an output folder with a base name. Pick the formats, press EXPORT.</p>'];
            T('text:Console') = '<p>For the expert: run any ADFNE library function against the current model from a command line, with the library''s own help beside it.</p>';
            % ------------------------------------------------------- Model tab
            T('RgnFields') = [ ...
                '<p>The block of rock, as six coordinates in your own units - metres, usually. Make it the volume you mapped or care about: ' ...
                'fractures are generated inside it and clipped to it, P32 and P21 are measured per unit of it, preset sizes are scaled to it, and the section plane offset is measured from its centre.</p>'];
            T('SetTable') = [ ...
                '<p>One row per joint set. Click a column heading or a cell to read about that column. The columns follow ADFNE''s conventions: ' ...
                'a scatter of 0 fixes the angle, a positive scatter is uniform plus or minus that many degrees, a negative one is a von Mises concentration; ' ...
                'sizes are diameters, drawn from the size law under Options and truncated to [Lmin, Lmax].</p>' ...
                '<p>The table may be empty - GENERATE and FIT say what to do then. FIT fills it from mapped data; Add set adds a row turned 90 degrees from the last.</p>'];
            T('SetTable:col:N') = '<p><b>How many</b> fractures of this set, in the whole domain - or, with the intensity measure set to P32 or P10 under Options, that intensity instead, and the column is headed so. The count is what the generator draws; an intensity is converted to a count by a calibration trial.</p>';
            T('SetTable:col:P32') = '<p><b>P32</b>: fracture area per unit volume of the domain for this set. Converted to a count by a fixed-seed calibration trial, so the generated network has this P32 on average.</p>';
            T('SetTable:col:P10') = '<p><b>P10</b>: fractures per unit length along a line through the domain (the section-plane normal). Converted to a count by a fixed-seed calibration trial.</p>';
            T('SetTable:col:Dip') = '<p><b>Mean dip</b> of the set, degrees from horizontal (0 flat, 90 vertical).</p>';
            T('SetTable:col:dDip') = '<p><b>Dip scatter.</b> 0 fixed; positive uniform plus or minus that many degrees; negative a von Mises kappa. Note ADFNE draws the dip scatter compressed by a quarter, so -30 here is about plus or minus 2.6 degrees - see the table tooltip for the conversion. Under the Fisher and other one-parameter models this column is the single concentration.</p>';
            T('SetTable:col:DipDir') = '<p><b>Mean dip direction</b>, degrees clockwise from north (the +Y axis of the domain).</p>';
            T('SetTable:col:dDDir') = '<p><b>Dip-direction scatter</b>, same convention as dDip but not compressed: -30 is about plus or minus 10 degrees.</p>';
            T('SetTable:col:Lmin') = '<p><b>Smallest size</b> (a diameter) a fracture of this set can have: the size law is truncated here.</p>';
            T('SetTable:col:Lmean') = '<p><b>The size law''s mean</b> before truncation (exponential, log-normal, normal, Weibull, gamma); unused by the power law and the uniform. Cutting off the small sizes lifts the realised mean - check the number the info box reports.</p>';
            T('SetTable:col:Lmax') = '<p><b>Largest size</b>: the upper truncation.</p>';
            T('SetTable:col:Lp') = '<p><b>The size law''s extra parameter</b>, headed by what it is: <code>L sd</code> for log-normal and normal, <code>L exp</code> the power-law exponent, <code>L shape</code> for Weibull and gamma; unused (<code>Lp -</code>) for the exponential, uniform and bootstrap.</p>';
            T('SetTable:col:L sd') = T('SetTable:col:Lp'); T('SetTable:col:L exp') = T('SetTable:col:Lp'); T('SetTable:col:L shape') = T('SetTable:col:Lp'); T('SetTable:col:Lp -') = T('SetTable:col:Lp');
            T('text:Add set') = '<p>Adds a joint set turned 90 degrees in dip direction from the last, with the default sizes, so two sets cross. Edit it in the table.</p>';
            T('text:Remove set') = '<p>Removes the selected row (the last, if none is selected). The table can be emptied.</p>';
            T('ShapeDD') = '<p>The polygon a fracture is: a regular polygon with the chosen number of facets (a disc, in the limit), an elongated one with an aspect ratio and a long-axis direction, a square, or ADFNE 1.0''s legacy quadrilateral.</p>';
            T('FacetSpin') = '<p>How many corners a polygon has. 24 is a disc for every purpose; fewer is faster and coarser.</p>';
            T('SizeLawDD') = [ ...
                '<p>The distribution fracture sizes (diameters) are drawn from, per set, truncated to the row''s [Lmin, Lmax]. The table''s Lmean and Lp columns take the meaning the law gives them, ' ...
                'and FIT estimates the law''s parameters from mapped data. Choose by what your data look like: exponential is ADFNE''s own and the classic Baecher assumption; ' ...
                'log-normal and power law are what trace-length surveys most often show; the bootstrap resamples mapped plane sizes as they are.</p>'];
            T('SizeLawDD:exp') = '<p><b>Exponential</b> - ADFNE''s own: mean Lmean, truncated. The Baecher model''s classic choice; light tail.</p>';
            T('SizeLawDD:logn') = '<p><b>Log-normal</b> - mean Lmean and standard deviation L sd of the untruncated law. Right-skewed; the common fit to trace lengths.</p>';
            T('SizeLawDD:pow') = '<p><b>Power law</b> - density proportional to L to the minus L exp on [Lmin, Lmax]; Lmean unused. Scale-free: exponents 2 to 3 are typical of fracture populations (Bonnet et al. 2001).</p>';
            T('SizeLawDD:unif') = '<p><b>Uniform</b> - every size in [Lmin, Lmax] equally likely. A test case more than a model.</p>';
            T('SizeLawDD:norm') = '<p><b>Normal</b> - mean Lmean, standard deviation L sd, cut at the range.</p>';
            T('SizeLawDD:weib') = '<p><b>Weibull</b> - mean Lmean and shape L shape (1 is exponential, larger is more peaked).</p>';
            T('SizeLawDD:gam') = '<p><b>Gamma</b> - mean Lmean and shape L shape (1 is exponential).</p>';
            T('SizeLawDD:boot') = '<p><b>Bootstrap</b> - the mapped 3D planes'' own sizes, resampled with replacement; needs planes loaded on the Conditioning tab, and refuses planes declared clipped at the band faces (their sizes are lower bounds).</p>';
            T('OrientDD') = [ ...
                '<p>How the pole of each fracture scatters about the set''s mean. It changes what the table''s two scatter columns mean and are headed. ' ...
                'ADFNE''s own draws dip and dip direction independently; Fisher is the standard isotropic model with one concentration; Kent, Bingham and the bivariate normal are the anisotropic ones ' ...
                '(elliptical scatter, or a girdle); bootstrap resamples mapped poles.</p>'];
            T('OrientDD:adfne') = '<p><b>dip, dipdir</b> - ADFNE''s own: each angle drawn on its own, uniform or von Mises, with the dip scatter compressed by a quarter. What the library does; not a spherical distribution.</p>';
            T('OrientDD:fisher') = '<p><b>Fisher</b> - the spherical normal: one concentration kappa (dDip column), isotropic about the mean pole. The usual choice; 20 to 50 for a well-defined set.</p>';
            T('OrientDD:boot') = '<p><b>Bootstrap</b> - the mapped planes'' own poles, resampled, optionally jittered by a Fisher draw (the jitter column). Needs planes loaded.</p>';
            T('OrientDD:bvn') = '<p><b>Bivariate normal</b> - two standard deviations in the tangent plane at the mean pole, along strike and down dip: elliptical scatter, in degrees.</p>';
            T('OrientDD:kent') = '<p><b>Kent</b> - the Fisher-Bingham 5-parameter distribution: a concentration and an ovalness, elliptical scatter on the sphere. Drawn exactly in its concentrated form.</p>';
            T('OrientDD:bingham') = '<p><b>Bingham</b> - antipodally symmetric, two concentrations: round clusters and girdles alike. Drawn by the Kent-Ganeiber-Mardia rejection sampler.</p>';
            T('IntensityDD') = '<p>What column 1 of the joint-set table holds: a count N, or an intensity P32 (area per volume) or P10 (fractures per length), converted to the count the generator needs by a fixed-seed calibration trial. P33 (volume per volume, from the flow aperture) is reported, not set.</p>';
            T('IntensityDD:N') = '<p><b>N per set</b> - the number of fractures the generator draws for the set, in the whole domain.</p>';
            T('IntensityDD:P32') = '<p><b>P32 per set</b> - fracture area per unit volume, the intensity FIT targets and the one that does not depend on fracture size for its meaning. Converted to N by a trial.</p>';
            T('IntensityDD:P10') = '<p><b>P10 per set</b> - fractures per unit length along the section-plane normal, what a scanline or borehole measures. Converted to N by a trial.</p>';
            T('CentresDD') = '<p>Where fracture centres go. Uniform (Poisson, the Baecher model) is independent centres; nearest-neighbour and Levy-Lee cluster them - new centres near existing ones, so the network is patchy at the chosen scale.</p>';
            T('CentresDD:poisson') = '<p><b>Uniform</b> - centres independent and uniform in the domain: the Baecher / Poisson model.</p>';
            T('CentresDD:nn') = '<p><b>Nearest-neighbour</b> - each new centre is placed at a distance drawn about a preferred spacing from an existing one: clustered.</p>';
            T('CentresDD:levy') = '<p><b>Levy-Lee</b> - a Levy flight: steps from the last centre with a power-law length, so clusters at every scale (fractal).</p>';
            T('TermField') = '<p><b>Enhanced Baecher.</b> The percentage of fractures that, on meeting an older fracture, stop at it instead of crossing. 0 is the plain Baecher model; 100 makes every intersection a T. Earlier sets are older.</p>';
            T('AspectField') = '<p>For elongated polygons: the long axis over the short, 1 being a regular polygon. The size drawn is the long-axis diameter.</p>';
            T('AspectLawDD') = '<p>How the aspect ratio varies from fracture to fracture: constant, or a law on the elongation (aspect minus 1) with the given spread, or resampled from mapped planes.</p>';
            T('AxisDD') = '<p>Which way the long axis points in the fracture plane: along strike, down dip, or random.</p>';
            T('SeedSpin') = '<p>The random seed. The same seed with the same inputs gives the same network, the same synthetic trace map or band, the same fit - reproducibility. Change it for another realisation.</p>';
            T('RandSeedCB') = '<p>Draw a new seed at every GENERATE, for a quick look at the variability between realisations. Untick to reproduce.</p>';
            T('ASepField') = '<p>Conditional simulation, angular separation: ADFNE''s rejection rule for the 2D synthetic trace map, and imposed in 3D on the generated network - fractures too close in orientation to a neighbour are rejected.</p>';
            T('DSepField') = '<p>Conditional simulation, distance separation: the same, on the distance between fractures.</p>';
            T('SecDipF') = '<p>The section plane''s dip. Viewing only: it chooses where the 2D view cuts the model and where the mapped face or band sits; the rock mass is the same whatever the plane.</p>';
            T('SecDirF') = '<p>The section plane''s dip direction, degrees clockwise from north.</p>';
            T('SecOffF') = '<p>How far the section plane sits from the domain centre, along its own normal, in domain units.</p>';
            T('PresetDD') = '<p>Typical joint-set tables (a few sets with plausible orientations and sizes scaled to the domain) to start from. Overwrites the table.</p>';
            % ------------------------------------------------------- Conditioning
            T('CondSrcDD') = '<p>What kind of field data you have, which changes the panel below and what FIT, Show, Compare and conditioning do.</p>';
            T('CondSrcDD:syn') = '<p><b>Synthetic traces</b> - 2D trace families authored from statistics (count, direction, kappa, length law) with ADFNE''s 2D generator. For trying the tools without a survey.</p>';
            T('CondSrcDD:file') = '<p><b>Trace map file</b> - <code>u1 v1 u2 v2 [set]</code>, one trace per line, in face coordinates and the domain''s units. Import file.</p>';
            T('CondSrcDD:syn3') = '<p><b>Synthetic 3D planes</b> - joint-plane families drawn from a statistics table into the band (count is the number in the band). The band boxes apply. For checking FIT against a known answer.</p>';
            T('CondSrcDD:file3') = '<p><b>Joint planes file</b> - <code>xc yc zc dip dipdir size [set]</code>, <code>xc yc zc nx ny nz radius [set]</code>, polygon corners in blank-line-separated blocks, or a .mat of corner lists; coordinates local to the band centre. See <code>examples\joint_planes</code>.</p>';
            T('BandThkF') = '<p>The band is the section plane given a thickness, centred on it and clipped to the domain: the slab your scan or photogrammetric plane-fit covered. Make it enclose the planes you mapped; the info box reports how far off the plane they lie.</p>';
            T('BandCutCB') = '<p>Which planes the band holds. Unticked: those whose centres lie in the band (no sampling bias). Ticked: every plane that cuts the band, as a scan records - large and steep planes are over-represented, and FIT weights each plane by 1/(thickness + its extent across the band) to undo that.</p>';
            T('BandClipCB') = '<p>The cutting planes are also clipped at the band faces, so their sizes are lower bounds. FIT then finds, by simulated sampling, the size scale at which planes drawn from the set and clipped the same way show the mean length that was measured (or the power-law exponent). The spread parameter stays as read.</p>';
            T('CondTable') = '<p>The statistics a synthetic map or band is drawn from: one row per family. Click a column to read about it.</p>';
            T('CondTable:col:N') = '<p><b>N</b> - traces in this family on the face, or planes in the band.</p>';
            T('CondTable:col:Dir (deg)') = '<p><b>Dir</b> - mean trace direction in the plane of the face, degrees from the face''s own u axis.</p>';
            T('CondTable:col:Kappa') = '<p><b>Kappa</b> - how tightly the directions cluster: a von Mises concentration, about 25 for a well-defined set, 0 for every direction.</p>';
            T('CondTable:col:L min') = '<p><b>L min</b> - the shortest trace: the length law is truncated here.</p>';
            T('CondTable:col:L mean') = '<p><b>L mean</b> - the length law''s mean, before truncation; the law is the size law chosen under Options.</p>';
            T('CondTable:col:L max') = '<p><b>L max</b> - the longest trace.</p>';
            T('CondTable:col:Lp -') = '<p><b>Lp</b> - the length law''s extra parameter, as on the joint-set table: sd, exponent or shape by the law.</p>';
            T('CondTable:col:L sd') = T('CondTable:col:Lp -'); T('CondTable:col:L exp') = T('CondTable:col:Lp -'); T('CondTable:col:L shape') = T('CondTable:col:Lp -');
            T('text:Add row') = '<p>Another synthetic family, turned 90 degrees from the last.</p>';
            T('text:Remove row') = '<p>Drop the selected row, or the last. The table can be emptied.</p>';
            T('text:Import file…') = '<p>Read a trace map or a joint-planes file; the layout is recognised from the columns. The source switches to the file.</p>';
            T('CondPreviewBtn') = '<p>Draw the field data FIT will read: the trace map on the 2D view, or the planes with the band in the 3D view. Press again to hide.</p>';
            T('FitBtn') = [ ...
                '<p><b>Inversion: from data to parameters.</b> From a trace map, simulated sampling: generate, section, compare, rescale - the size scale so the mean trace length matches, then the count so P21 matches ' ...
                '(orientation cannot be read from one face). From planes in a band: orientation by circular means and concentrations, sizes by the chosen law, the count so P32 in the band matches; ' ...
                'with the band boxes ticked, weighted for the cutting bias and corrected for the clip. The joint-set table on the Model tab is rewritten; the fit results table shows before and after.</p>'];
            T('CondCompareBtn') = '<p>The generated model against the data, in a window of its own: counts and intensities against sqrt(n), sizes and orientations by Kolmogorov-Smirnov and Kuiper tests, topology of the trace map (Sanderson-Nixon I/Y/X), maps and stereonets. Needs a generated model.</p>';
            T('CondRestoreBtn') = '<p>Put the joint-set table back as it was before FIT rewrote it.</p>';
            T('CondCB') = '<p><b>Conditioning proper.</b> Ticked, GENERATE builds every mapped trace or plane into the model exactly - a trace fixes the fracture''s plane and its size covers the trace; a 3D plane goes in as it is - and the stochastic network is generated around them. Untick for a purely stochastic model.</p>';
            T('CondExclCB') = '<p>With conditioning on: reject stochastic fractures that would cut the mapped face (or reach into the band), because the map says there are no others. Untick if the map is a sample rather than a complete survey.</p>';
            T('CondSetDD') = '<p>Which joint set the mapped features belong to, for their missing parameters (a trace''s rotation about its line, its size). Auto assigns each to the set whose mean orientation is nearest.</p>';
            T('FitTable') = '<p>Before and after FIT, per parameter, so you can see what the data changed.</p>';
            T('CondInfo') = '<p>What the field data holds: counts, lengths or sizes, orientations, intensities, and warnings when the data and the face or band disagree.</p>';
            % ------------------------------------------------------- viewport
            T('ModeDD') = '<p><b>How you look, not what is built.</b> The network is always 3D; the 2D view is the traces where the section plane cuts it - a tunnel face. Switching never regenerates. The Analysis list follows the view.</p>';
            T('SecShowCB') = '<p>Draw the section plane through the 3D model, and enable clipping the blocks either side of it.</p>';
            T('SecClipDD') = '<p>A viewing aid: hide the block in front of or behind the section plane, or show only the fractures that cut it. The model is untouched.</p>';
            T('PlotDD') = '<p>What is drawn: the network, then whatever the analyses have produced - clusters, traces, density and connectivity fields, the pipe model, flow pressures and rates, the mapped data, the band.</p>';
            T('ColorDD') = '<p>Set colours each joint set (the same colour everywhere in the app); cluster colours connected groups after an intersection analysis; uniform is one colour.</p>';
            T('RenderBtn') = '<p>Draw the current plot. With Auto-render on this happens by itself; for a large model untick it, adjust, then RENDER once.</p>';
            T('text:Auto-render') = '<p>Redraw on every change. Untick for large models, and press RENDER when ready.</p>';
            T('text:Reset view') = '<p>Back to the default camera for this plot.</p>';
            T('text:Fit') = '<p>Zoom so the whole model fits the viewport.</p>';
            T('text:Pop out') = '<p>A copy of the current plot in a plain figure window, to keep, resize or edit with MATLAB''s tools.</p>';
            T('DockToggleBtn') = '<p>Show or hide the display controls: opacity, line width, colormap, lighting, grid, colorbar, and the camera azimuth and elevation.</p>';
            T('LogToggleBtn') = '<p>Expand or collapse the activity log: everything the app did, with warnings and errors, newest at the top. The one-line strip shows the latest entry or the tooltip of the control in focus.</p>';
            T('AlphaSld') = '<p>How transparent the fractures are drawn. Lower to see inside a dense model.</p>';
            T('LWSpin') = '<p>Line width of traces and edges.</p>';
            T('CmapDD') = '<p>The colour scale for fields and for cluster colouring.</p>';
            T('AzSld') = '<p>Camera azimuth, degrees around the vertical.</p>';
            T('ElSld') = '<p>Camera elevation, degrees above the horizontal.</p>';
            % ------------------------------------------------------- Analysis
            T('AnaList') = '<p>Select one or several (Ctrl/Shift); the parameter panel below shows what they need. Each entry names the ADFNE function it runs.</p>';
            T('AnaList:Intersections + clusters') = '<p>Every pair of intersecting fractures, and the connected clusters they form - the backbone of connectivity, the pipe model and the flow solve. Colour by cluster afterwards.</p>';
            T('AnaList:Pipe model') = '<p>The network as pipes between intersection centres, ready for the flow solve.</p>';
            T('AnaList:Traces on plane') = '<p>The traces the section plane cuts, as lines: what a face would show.</p>';
            T('AnaList:Intensity P10/P21/P32') = '<p>The standard intensities: fractures per length along a line, trace length per area on the section, fracture area per volume in the domain.</p>';
            T('AnaList:Orientation') = '<p>Dip and dip direction of every fracture, with means and concentrations per set, and a stereonet.</p>';
            T('AnaList:Sizes') = '<p>The size of every fracture, with the distribution per set.</p>';
            T('AnaList:Borehole sampling') = '<p>What a borehole through the model would log: intersections along a line, spacing, P10, RQD-style statistics.</p>';
            T('AnaList:Connectivity matrix') = '<p>Which fracture touches which, as a matrix.</p>';
            T('AnaList:Graph metrics') = '<p>The network as a graph: degree, components, path lengths - the measures of connectivity.</p>';
            T('AnaList:Density map') = '<p>Trace density on the section, on a grid.</p>';
            T('AnaList:Connectivity field') = '<p>Connectivity on the section, on a grid: how well each point is connected through the traces.</p>';
            T('AnaList:Variogram') = '<p>Spatial correlation of a result grid: the variogram cloud and its model.</p>';
            T('AnaList:Kriging map') = '<p>Interpolate a result grid by kriging.</p>';
            T('AnaList:Upscale a result grid') = '<p>Average a result grid to a coarser one: block properties for a continuum model.</p>';
            T('AnaList:Statistics') = '<p>Summary statistics of sizes or lengths and orientations, per set.</p>';
            T('AnaRunBtn') = '<p>Run the selected analyses with the parameters set below; results go to the table and unlock their plots.</p>';
            T('ResTable') = '<p>Everything measured so far, with the function that measured it. Clear results empties it.</p>';
            % ------------------------------------------------------- Flow
            T('FlowDirDD') = '<p>Which pair of opposite domain faces the head difference is imposed across; the conductivity is for that direction.</p>';
            T('FlowBCDD') = '<p>The four side faces: no flow (sealed), or a linear head between inlet and outlet (a permeameter with a uniform gradient).</p>';
            T('FlowMtdDD') = '<p>How pipes are built from intersections: from their centres, or by triangulating each fracture.</p>';
            T('FlowPinF') = '<p>Head at the inlet face.</p>';
            T('FlowPoutF') = '<p>Head at the outlet face.</p>';
            T('FlowApF') = '<p>Hydraulic aperture of every fracture; conductance goes as the cube (the cubic law). Also gives P33 on the Model tab.</p>';
            T('FlowKvF') = '<p>Kinematic viscosity of the fluid; water at 20 C is about 1e-6 m2/s.</p>';
            T('FlowRunBtn') = '<p>Build the pipe network if needed and solve: heads at every node, flow in every pipe, and the equivalent hydraulic conductivity of the block.</p>';
            % ------------------------------------------------------- export
            T('OutDirField') = '<p>Where exported files and the default session file go.</p>';
            T('BaseNameField') = '<p>The stem of every exported file name.</p>';
            T('FmtList') = '<p>Which files to write: the picture (PNG, PDF, SVG, FIG) and the model (VTK, MAT, CSV).</p>';
        end
    end
end
