import { Component, Input } from '@angular/core';

@Component({
  selector: 'app-icon-info',
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
      <path d="M12 16v-4" />
      <path d="M12 8h.01" />
    </svg>
  `,
  styles: [':host { display: inline-flex; }']
})
export class IconInfoComponent {
  @Input() size: number = 16;
}
