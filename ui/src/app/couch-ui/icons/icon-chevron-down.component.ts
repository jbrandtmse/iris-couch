import { Component, Input } from '@angular/core';

@Component({
  selector: 'app-icon-chevron-down',
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
      <path d="m6 9 6 6 6-6" />
    </svg>
  `,
  styles: [':host { display: inline-flex; }']
})
export class IconChevronDownComponent {
  @Input() size: number = 16;
}
