import { Component, Input } from '@angular/core';

@Component({
  selector: 'app-icon-check-circle',
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
      <circle cx="12" cy="12" r="10" />
      <path d="m9 12 2 2 4-4" />
    </svg>
  `,
  styles: [':host { display: inline-flex; }']
})
export class IconCheckCircleComponent {
  @Input() size: number = 16;
}
