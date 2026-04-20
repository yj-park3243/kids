import { Navigate } from 'react-router-dom';
import { authStore } from '../stores/authStore';

interface Props {
  children: React.ReactNode;
}

export default function ProtectedRoute({ children }: Props) {
  if (!authStore.isLoggedIn()) {
    return <Navigate to="/login" replace />;
  }
  return <>{children}</>;
}
