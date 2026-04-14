import { Component, Input } from '@angular/core';

@Component({
  selector: 'app-icon-search',
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
      <circle cx="11" cy="11" r="8" />
      <path d="m21 21-4.34-4.34" />
    </svg>
  `,
  styles: [':host { display: inline-flex; }']
})
export class IconSearchComponent {
  @Input() size: number = 16;
}
