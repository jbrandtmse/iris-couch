import { Component, Input } from '@angular/core';

@Component({
  selector: 'app-icon-plus',
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
      <path d="M5 12h14" />
      <path d="M12 5v14" />
    </svg>
  `,
  styles: [':host { display: inline-flex; }']
})
export class IconPlusComponent {
  @Input() size: number = 16;
}
