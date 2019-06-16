-- Author: Vic Fryzel, Toni Uhlig
-- http://github.com/vicfryzel/xmonad-config
-- https://github.com/lnslbrty/foo-scripts/blob/master/configs/xmonad.hs
 
import System.IO
import System.Exit
import XMonad
import XMonad.Hooks.DynamicLog
import XMonad.Hooks.ManageDocks
import XMonad.Hooks.ManageHelpers
import XMonad.Hooks.SetWMName
import XMonad.Hooks.EwmhDesktops
import XMonad.Hooks.UrgencyHook
import XMonad.Layout.NoBorders
import XMonad.Layout.Tabbed
import XMonad.Layout.Grid
import XMonad.Layout.PerWorkspace
import XMonad.Layout.FixedColumn
import XMonad.Layout.IM
import XMonad.Actions.SpawnOn
import XMonad.Actions.PhysicalScreens
import XMonad.Actions.CycleWS
import XMonad.Util.Replace
import XMonad.Util.Run
import XMonad.Util.EZConfig(additionalKeys)
import XMonad.Util.NamedScratchpad
import qualified XMonad.StackSet as W
import qualified Data.Map as M


------------------------------------------------------------------------
-- Terminal
-- The preferred terminal program, which is used in a binding below and by
-- certain contrib modules.
--
myTerminal = "x-terminal-emulator"

------------------------------------------------------------------------
-- Workspaces
-- The default number of workspaces (virtual screens) and their names.
--
comWS  = "1:com"
fileWS = "2:mail"
webWS  = "3:web"
w1WS   = "4:work1"
w2WS   = "5:work2"
myWorkspaces :: [WorkspaceId]
myWorkspaces = [ comWS, fileWS, webWS, w1WS, w2WS ] ++ map show [6..9]
 
------------------------------------------------------------------------
-- Window rules
-- Execute arbitrary actions and WindowSet manipulations when managing
-- a new window. You can use this to, for example, always float a
-- particular program, or have a client always appear on a particular
-- workspace.
--
-- To find the property name associated with a program, use
-- rkspac
-- > xprop | grep WM_CLASS
-- and click on the client you're interested in.
--
-- To match on the WM_NAME, you can use 'title' in the same way that
-- 'className' and 'resource' are used below.
--
myManageHook = composeAll
    [ className =? "Seahorse" --> doShift webWS
    , className =? "Iceweasel" --> doShift webWS
    , className =? "chromium" --> doShift webWS
    , className =? "Chromium" --> doShift webWS
    , resource =? "browser" --> doShift webWS
    , className =? "chromium-browser" --> doShift webWS
    , className =? "Chromium-browser" --> doShift webWS
    , className =? "Icedove" --> doShift webWS
    , className =? "Pidgin" --> doShift comWS
    , className =? "qTox" --> doShift comWS
    , className =? "telegram-desktop" --> doShift comWS
    , className =? "crx_clhhggbfdinjmjhajaheehoeibfljjno" --> doShift comWS
    , className =? "TelegramDesktop" --> doShift comWS
    , className =? "crx_bikioccmkafdpakkkcpdbppfkghcmihk" --> doShift comWS
    , className =? "Eclipse" --> doShift fileWS
    , className =? "Kmail" --> doShift webWS
    , className =? "Konqueror" --> doShift fileWS
    , className =? "Nautilus" --> doShift fileWS
    , resource =? "desktop_window" --> doIgnore
    , className =? "Galculator" --> doFloat
    , className =? "Gource" --> doFloat
    , className =? "MPlayer" --> doFloat
    , className =? "VirtualBox" --> doShift w1WS
    , className =? "Xchat" --> doShift w2WS
    , className =? "claws-mail" --> doShift fileWS
    , className =? "Claws-mail" --> doShift fileWS
    , className =? "notes" --> nonFloating
    , className =? "xmobar" --> doIgnore
    , isFullscreen --> (doF W.focusDown <+> doFullFloat)]


------------------------------------------------------------------------
-- Layouts
-- You can specify and transform your layouts by modifying these values.
-- If you change layout bindings be sure to use 'mod-shift-space' after
-- restarting (with 'mod-q') to reset your layout state to the new
-- defaults, as xmonad preserves your old layout settings by default.
--
-- The available layouts. Note that each layout is separated by |||,
-- which denotes layout choice.
--
comLayout =
    withIM (1/6) (Or
      (Title "Buddy-Liste")
      (Title "Buddy List"))
      Grid
fileLayout = tabbed shrinkText myTabConfig
webLayout  = Full
myLayout = avoidStruts $
    onWorkspace comWS  comLayout $
    onWorkspace fileWS fileLayout $
    onWorkspace webWS  webLayout $
      Mirror (Tall 1 (3/100) (1/2)) |||
      Tall 1 (3/100) (1/2) |||
      Grid |||
      FixedColumn 1 20 80 10 |||
      Full |||
      tabbed shrinkText myTabConfig

------------------------------------------------------------------------
-- Colors and borders
-- Currently based on the ir_black theme.
--
myNormalBorderColor = "#7c7c7c"
myFocusedBorderColor = "#ff0000"

-- Colors for text and backgrounds of each tab when in "Tabbed" layout.
myTabConfig = defaultTheme {
    activeBorderColor = "#7C7C7C",
    activeTextColor = "#CEFFAC",
    activeColor = "#445566",
    inactiveBorderColor = "#7C7C7C",
    inactiveTextColor = "#EEEEEE",
    inactiveColor = "#000000"
}

-- Color of current window title in xmobar.
xmobarTitleColor = "#FFB6B0"

-- Color of current workspace in xmobar.
xmobarCurrentWorkspaceColor = "#CEFFAC"

-- Width of the window border in pixels.
myBorderWidth = 1


------------------------------------------------------------------------
-- Key bindings
--
-- modMask lets you specify which modkey you want to use. The default
-- is mod1Mask ("left alt"). You may also consider using mod3Mask
--
-- "windows key" is usually mod4Mask.
--
myModMask = mod1Mask
 
myKeys conf@(XConfig {XMonad.modMask = modMask}) = M.fromList $
  ----------------------------------------------------------------------
  -- Custom key bindings
  --
  -- Start a terminal. Terminal to start is specified by myTerminal variable.
  [ ((modMask .|. shiftMask, xK_Return),
     spawn $ XMonad.terminal conf)

  -- Lock the screen using xscreensaver.
  , ((modMask .|. shiftMask, xK_l),
     spawn "xtrlock")

  -- Start chromium.sh
  , ((0                    , 0x1008ff18),
     spawn "chromium.sh")

  -- Start claws.sh
  , ((0                    , 0x1008ff19),
     spawn "claws.sh")

  , ((0                    , 0x1008ff1b),
     spawn "chromium duckduckgo.com")

  -- run demnu
  , ((modMask .|. shiftMask, xK_d),
     spawn "dmenu_run -b")

  -- Take a screenshot from the window on which the user clicks
  , ((0, xK_Print),
     spawn "xwd -out ~/screenshot.xwd; convert ~/screenshot.xwd ~/screenshot.jpg")
  -- Take full screenshot in multi-head mode.
  -- That is, take a screenshot of everything you see.
  , ((modMask .|. shiftMask, xK_Print),
     spawn "xwd -root -out ~/screenshot_full.xwd; convert ~/screenshot_full.xwd ~/screenshot_full.jpg")

  -- Mute volume.
  , ((modMask .|. shiftMask, xK_m),
     spawn "amixer -q set Master toggle")

  -- Decrease volume.
  , ((modMask .|. shiftMask, xK_j),
     spawn "amixer -q set Master 5%-")

  -- Increase volume.
  , ((modMask .|. shiftMask, xK_k),
     spawn "amixer -q set Master 5%+")

  -- Mute volume multimedia key.
  , ((0                    , 0x1008ff12),
     spawn "amixer -q set Master toggle")

  -- Decrease volumt multimedia key.
  , ((0                    , 0x1008ff11),
    spawn "amixer -q set Master 5%-")

  -- Increase volume multimedia key.
  , ((0                    , 0x1008ff13),
    spawn "amixer -q set Master 5%+")

  --------------------------------------------------------------------
  -- "Standard" xmonad key bindings
  --

  -- switch to next physicial monitor
  , ((modMask .|. shiftMask, xK_x), onNextNeighbour W.view)

  -- suspend to ram
  , ((modMask .|. shiftMask, xK_s), spawn "xtrlock && sudo /usr/sbin/s2ram --force")

  -- Close focused window.
  , ((modMask .|. shiftMask, xK_c),
     kill)

  -- Cycle through the available layout algorithms.
  , ((modMask, xK_space),
     sendMessage NextLayout)

  -- Reset the layouts on the current workspace to default.
  , ((modMask .|. shiftMask, xK_space),
     setLayout $ XMonad.layoutHook conf)

  -- Resize viewed windows to the correct size.
  , ((modMask, xK_n),
     refresh)

  , ((modMask, xK_Left),
     prevWS)

  , ((modMask, xK_Right),
     nextWS)

  , ((modMask, xK_Up),
     windows W.focusUp)

  , ((modMask, xK_Down),
     windows W.focusDown)

  -- Move focus to the next window.
  , ((modMask, xK_Tab),
     windows W.focusDown)

  -- Move focus to the next window.
  , ((modMask, xK_j),
     windows W.focusDown)

  -- Move focus to the previous window.
  , ((modMask, xK_k),
     windows W.focusUp )

  -- Move focus to the master window.
  , ((modMask, xK_m),
     windows W.focusMaster )

  -- Swap the focused window and the master window.
  , ((modMask, xK_Return),
     windows W.swapMaster)

  -- Swap the focused window with the next window.
  , ((modMask .|. shiftMask, xK_j),
     windows W.swapDown )

  -- Swap the focused window with the previous window.
  , ((modMask .|. shiftMask, xK_k),
     windows W.swapUp )

  -- Shrink the master area.
  , ((modMask, xK_h),
     sendMessage Shrink)

  -- Expand the master area.
  , ((modMask, xK_l),
     sendMessage Expand)

  -- ToggleStruts
  , ((modMask, xK_b),
     sendMessage ToggleStruts)

  -- Push window back into tiling.
  , ((modMask, xK_t),
     withFocused $ windows . W.sink)

  -- Toggle the status bar gap.
  -- TODO: update this binding with avoidStruts, ((modMask, xK_b),

  -- Quit xmonad.
  , ((modMask .|. shiftMask, xK_q),
       spawn "/sbin/start-stop-daemon -S -b --exec /usr/bin/killall -- -TERM -u `id -nu`")
  ]
  ++
 
  -- mod-[1..9], Switch to workspace N
  -- mod-shift-[1..9], Move client to workspace N
  [((m .|. modMask, k), windows $ f i)
      | (i, k) <- zip (XMonad.workspaces conf) [xK_1 .. xK_9]
      , (f, m) <- [(W.greedyView, 0), (W.shift, shiftMask)]]
  ++

  -- mod-{w,e,r}, Switch to physical/Xinerama screens 1, 2, or 3
  -- mod-shift-{w,e,r}, Move client to screen 1, 2, or 3
  [((m .|. modMask, key), screenWorkspace sc >>= flip whenJust (windows . f))
      | (key, sc) <- zip [xK_w, xK_e, xK_r] [0..]
      , (f, m) <- [(W.view, 0), (W.shift, shiftMask)]]
 
 
------------------------------------------------------------------------
-- Mouse bindings
--
-- Focus rules
-- True if your focus should follow your mouse cursor.
myFocusFollowsMouse :: Bool
myFocusFollowsMouse = False
 
myMouseBindings (XConfig {XMonad.modMask = modMask}) = M.fromList $
  [
    -- mod-button1, Set the window to floating mode and move by dragging
    ((modMask, button1),
     (\w -> focus w >> mouseMoveWindow w))
 
    -- mod-button2, Raise the window to the top of the stack
    , ((modMask, button2),
       (\w -> focus w >> windows W.swapMaster))
 
    -- mod-button3, Set the window to floating mode and resize by dragging
    , ((modMask, button3),
       (\w -> focus w >> mouseResizeWindow w))
 
    -- you may also bind events to the mouse scroll wheel (button4 and button5)
  ]
 

------------------------------------------------------------------------
-- Status bars and logging
-- Perform an arbitrary action on each internal state change or X event.
-- See the 'DynamicLog' extension for examples.
--
-- To emulate dwm's status bar
--
-- > logHook = dynamicLogDzen
--
 

------------------------------------------------------------------------
-- Startup hook
-- Perform an arbitrary action each time xmonad starts or is restarted
-- with mod-q. Used by, e.g., XMonad.Layout.PerWorkspace to initialize
-- per-workspace layout choices.
--
-- By default, do nothing.
--myStartupHook = return ()
myStartupHook :: X ()
myStartupHook = do
                safeSpawnProg "seahorse"
                safeSpawnProg "chromium"
                safeSpawnProg "pidgin.sh"
                safeSpawnProg "claws.sh"
		setWMName "LG3D"
                nextWS
                nextWS
 

------------------------------------------------------------------------
-- Run xmonad with all the defaults we set up.
--
main = do
  replace
  xmproc <- spawnPipe "/usr/bin/xmobar ~/.xmobarrc"
  xmonad $ withUrgencyHook dzenUrgencyHook { args = ["-bg", "darkgreen", "-xs", "1"] }
         $ defaults {
               logHook = dynamicLogWithPP $ xmobarPP {
               ppOutput = hPutStrLn xmproc
             , ppTitle = xmobarColor xmobarTitleColor "" . shorten 100
             , ppCurrent = xmobarColor xmobarCurrentWorkspaceColor ""
             , ppSep = " "}
             , manageHook = myManageHook <+> manageSpawn <+> manageDocks
           }
 

------------------------------------------------------------------------
-- Combine it all together
-- A structure containing your configuration settings, overriding
-- fields in the default config. Any you don't override, will
-- use the defaults defined in xmonad/XMonad/Config.hs
-- 
-- No need to modify this.
--
defaults = defaultConfig {
    -- simple stuff
    terminal = myTerminal,
    focusFollowsMouse = myFocusFollowsMouse,
    borderWidth = myBorderWidth,
    modMask = myModMask,
    workspaces = myWorkspaces,
    normalBorderColor = myNormalBorderColor,
    focusedBorderColor = myFocusedBorderColor,
 
    -- key bindings
    keys = myKeys,
    mouseBindings = myMouseBindings,
 
    -- hooks, layouts
    startupHook = myStartupHook,
    layoutHook = smartBorders $ myLayout,
    manageHook = myManageHook
}
