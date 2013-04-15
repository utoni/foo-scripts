package org.jdownloader.extensions.minjd;

import java.awt.Toolkit;
import java.io.File;
import java.io.FilenameFilter;

import jd.controlling.JSonWrapper;
import jd.controlling.downloadcontroller.DownloadWatchDog;
import jd.gui.swing.jdgui.JDGui;
import jd.plugins.AddonPanel;
import org.jdownloader.extensions.AbstractExtension;
import org.jdownloader.extensions.ExtensionConfigPanel;
import org.jdownloader.extensions.StartException;
import org.jdownloader.extensions.StopException;

public class minjdExtension extends AbstractExtension<minjdConfig> {

	public static final String EXTENSION_NAME = "MinJD";
	public static final String CONFIG_ID = "minjd";
	public static final String AUTHOR_NAME = "dev0";
	public static final String DESC = "minimal JD Gui";

	public minjdExtension() {
		super(EXTENSION_NAME);
	}

	public void cleanPartFiles() {
		String dest = JSonWrapper.get(
				"org.jdownloader.settings.GeneralSettings").getStringProperty(
				"defaultdownloadfolder");
		File dir = new File(dest);
		String[] partfiles = dir.list(new FilenameFilter() {
			public boolean accept(File d, String name) {
				return name.endsWith(".part");
			}
		});

		for (String s : partfiles) {
			if(!new File(dest + "/" + s).delete()) logger.info(EXTENSION_NAME + ": can not delete file: " + s);
		}
	}

	@Override
	protected void stop() throws StopException {
		logger.info("MinJD STOPPED!");
	}

	@Override
	protected void start() throws StartException {
		logger.info("MinJD OK");
		jd.gui.swing.jdgui.menu.PremiumMenu.getInstance().setEnabled(false);
		jd.gui.swing.jdgui.menu.AddonsMenu.getInstance().setEnabled(false);
		jd.gui.swing.jdgui.menu.WindowMenu.getInstance().setEnabled(false);
		jd.gui.swing.SwingGui.getInstance().getMainFrame().getJMenuBar()
				.setVisible(false);
		jd.gui.swing.jdgui.components.premiumbar.PremiumStatus.getInstance()
				.setEnabled(false);
		jd.gui.swing.jdgui.components.premiumbar.PremiumStatus.getInstance()
				.setVisible(false);
		jd.gui.swing.jdgui.components.toolbar.MainToolBar.getInstance()
				.setList(
						new String[] {
								"toolbar.control.start",
								"toolbar.control.stop",
								"toolbar.separator",
								// "action.settings",
								"toolbar.quickconfig.clipboardoberserver",
								"toolbar.control.stopmark",
								"toolbar.separator",
								"toolbar.interaction.update" });
		JDGui.getInstance().getMainTabbedPane().removeTabAt(2);

		JDGui.getInstance().getMainFrame().setLocation(0, 0);
		JDGui.getInstance().getMainFrame()
				.setSize(Toolkit.getDefaultToolkit().getScreenSize());

		cleanPartFiles();
		DownloadWatchDog.getInstance().startDownloads();
	}

	@Override
	protected void initExtension() throws StartException {
		logger.info("MinJD INIT");
	}

	@Override
	public ExtensionConfigPanel<minjdExtension> getConfigPanel() {
		return null;
	}

	@Override
	public boolean hasConfigPanel() {
		return false;
	}

	@Override
	public String getConfigID() {
		return CONFIG_ID;
	}

	@Override
	public String getAuthor() {
		return AUTHOR_NAME;
	}

	@Override
	public String getDescription() {
		return DESC;
	}

	@Override
	public AddonPanel<minjdExtension> getGUI() {
		return null;
	}

}
