import { Component, Input } from '@angular/core';

@Component({
  selector: 'app-icon-x',
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
      <path d="M18 6 6 18" />
      <path d="m6 6 12 12" />
    </svg>
  `,
  styles: [':host { display: inline-flex; }']
})
export class IconXComponent {
  @Input() size: number = 16;
}
