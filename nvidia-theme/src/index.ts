import {
  JupyterFrontEnd,
  JupyterFrontEndPlugin
} from '@jupyterlab/application';

import { IThemeManager } from '@jupyterlab/apputils';

/**
 * NVIDIA theme plugin
 */
const plugin: JupyterFrontEndPlugin<void> = {
  id: '@nvidia/jupyterlab-theme:plugin',
  requires: [IThemeManager],
  activate: (app: JupyterFrontEnd, manager: IThemeManager) => {
    const style = '@nvidia/jupyterlab-theme/index.css';
    
    manager.register({
      name: 'NVIDIA Dark',
      isLight: false,
      themeScrollbars: true,
      load: () => manager.loadCSS(style),
      unload: () => Promise.resolve(undefined)
    });
  },
  autoStart: true
};

export default plugin;

