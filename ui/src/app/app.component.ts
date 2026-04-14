import { Component } from '@angular/core';
import { AppShellComponent } from './couch-ui/app-shell/app-shell.component';
import { ShortcutOverlayComponent } from './couch-ui/shortcut-overlay/shortcut-overlay.component';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [AppShellComponent, ShortcutOverlayComponent],
  templateUrl: './app.component.html',
  styleUrl: './app.component.css'
})
export class AppComponent {
  title = 'iris-couch-ui';
}
