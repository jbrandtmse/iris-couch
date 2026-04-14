import { Component, Input } from '@angular/core';

@Component({
  selector: 'app-icon-menu',
  standalone: true,
  template: `
    <svg
      [attr.width]="size"
      [attr.height]="size"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true">
      <path d="M4 5h16" />
      <path d="M4 12h16" />
      <path d="M4 19h16" />
    </svg>
  `,
  styles: [':host { display: inline-flex; }']
})
export class IconMenuComponent {
  @Input() size: number = 16;
}
