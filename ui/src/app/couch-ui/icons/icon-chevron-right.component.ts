import { Component, Input } from '@angular/core';

@Component({
  selector: 'app-icon-chevron-right',
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
      <path d="m9 18 6-6-6-6" />
    </svg>
  `,
  styles: [':host { display: inline-flex; }']
})
export class IconChevronRightComponent {
  @Input() size: number = 16;
}
