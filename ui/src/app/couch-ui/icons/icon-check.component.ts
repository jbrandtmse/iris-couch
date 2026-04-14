import { Component, Input } from '@angular/core';

@Component({
  selector: 'app-icon-check',
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
      <path d="M20 6 9 17l-5-5" />
    </svg>
  `,
  styles: [':host { display: inline-flex; }']
})
export class IconCheckComponent {
  @Input() size: number = 16;
}
