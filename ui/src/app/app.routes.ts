import { Routes } from '@angular/router';
import { authGuard } from './guards/auth.guard';
import { LoginComponent } from './features/auth/login.component';
import { DatabaseListComponent } from './features/databases/database-list.component';
import { DatabaseDetailComponent } from './features/database/database-detail.component';
import { DocumentDetailComponent } from './features/document/document-detail.component';

export const routes: Routes = [
  { path: 'login', component: LoginComponent },
  { path: 'databases', component: DatabaseListComponent, canActivate: [authGuard] },
  { path: 'db/:dbname', component: DatabaseDetailComponent, canActivate: [authGuard] },
  { path: 'db/:dbname/doc/:docid', component: DocumentDetailComponent, canActivate: [authGuard] },
  { path: '', redirectTo: 'databases', pathMatch: 'full' },
  { path: '**', redirectTo: 'databases' },
];
