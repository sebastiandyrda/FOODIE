!< Define Euler 1D (CAF enabled) field without extending FOODIE integrand.
module type_euler_1D_caf_no_foodie
!-----------------------------------------------------------------------------------------------------------------------------------
!< Define Euler 1D (CAF enabled) field without extending FOODIE integrand.
!-----------------------------------------------------------------------------------------------------------------------------------

!-----------------------------------------------------------------------------------------------------------------------------------
use IR_Precision, only : R_P, I_P
use wenoof, only : weno_factory, weno_constructor_upwind, weno_interpolator, weno_interpolator_upwind
!-----------------------------------------------------------------------------------------------------------------------------------

!-----------------------------------------------------------------------------------------------------------------------------------
implicit none
private
public :: euler_1D_caf_nf
public :: tvd_runge_kutta_integrator
!-----------------------------------------------------------------------------------------------------------------------------------

!-----------------------------------------------------------------------------------------------------------------------------------
type :: euler_1D_caf_nf
  !< Euler 1D (CAF enabled) PDEs system field.
  !<
  !< @note This object does not use FOODIE.
  !<
  !<### 1D Euler PDEs system
  !< The 1D Euler PDEs system considered is a non linear, hyperbolic (inviscid) system of conservation laws for compressible gas
  !< dynamics, that reads as
  !<$$
  !<\begin{matrix}
  !<U_t = R(U)  \Leftrightarrow U_t = F(U)_x \\
  !<U = \begin{bmatrix}
  !<\rho \\
  !<\rho u \\
  !<\rho E
  !<\end{bmatrix}\;\;\;
  !<F(U) = \begin{bmatrix}
  !<\rho u \\
  !<\rho u^2 + p \\
  !<\rho u H
  !<\end{bmatrix}
  !<\end{matrix}
  !<$$
  !< where \(\rho\) is the density, \(u\) is the velocity, \(p\) the pressure, \(E\) the total internal specific energy and \(H\)
  !< the total specific enthalpy. The PDEs system must completed with the proper initial and boundary conditions. Moreover, an ideal
  !< (thermally and calorically perfect) gas is considered
  !<$$
  !<\begin{matrix}
  !<R = c_p - c_v \\
  !<\gamma = \frac{c_p}{c_v}\\
  !<e = c_v T \\
  !<h = c_p T
  !<\end{matrix}
  !<$$
  !< where *R* is the gas constant, \(c_p\,c_v\) are the specific heats at constant pressure and volume (respectively), *e* is the
  !< internal energy, *h* is the internal enthalpy and *T* is the temperature. The following addition equations of state hold:
  !<$$
  !<\begin{matrix}
  !<T = \frac{p}{\rho R} \\
  !<E = \rho e + \frac{1}{2} \rho u^2 \\
  !<H = \rho h + \frac{1}{2} \rho u^2 \\
  !<a = \sqrt{\frac{\gamma p}{\rho}}
  !<\end{matrix}
  !<$$
  !<
  !<### Multi-fluid Euler PDEs system
  !< An extension of the above Euler system is considered allowing the modelling of a multi-fluid mixture of different gas (with
  !< different physical characteristics). The well known Standard Thermodynamic Model is used to model the gas mixture replacing the
  !< density with the density fraction of each specie composing the mixture. This led to the following system:
  !<$$
  !<\begin{matrix}
  !<U_t = R(U)  \Leftrightarrow U_t = F(U)_x \\
  !<U = \begin{bmatrix}
  !<\rho_s \\
  !<\rho u \\
  !<\rho E
  !<\end{bmatrix}\;\;\;
  !<F(U) = \begin{bmatrix}
  !<\rho_s u \\
  !<\rho u^2 + p \\
  !<\rho u H
  !<\end{bmatrix}\;\;\; for\; s=1,2,...N_s \\
  !<\rho = \sum_{s=1}^{N_s}\rho_s \\
  !<c_p = \sum_{s=1}^{N_S} \frac{\rho_s}{\rho} c_{p,s} \quad  c_v = \sum_{s=1}^{N_S} \frac{\rho_s}{\rho} c_{v,s}
  !<\end{matrix}
  !<$$
  !< where \(N_s\) is the number of initial species composing the gas mixture.
  !<
  !<#### Numerical grid organization
  !< The finite volume, Godunov's like approach is employed. The conservative variables (and the primitive ones) are co-located at
  !< the cell center. The cell and (inter)faces numeration is as follow.
  !<```
  !<                cell            (inter)faces
  !<                 |                   |
  !<                 v                   v
  !<     |-------|-------|-.....-|-------|-------|-------|-------|-.....-|-------|-------|-------|-.....-|-------|-------|
  !<     | 1-Ng  | 2-Ng  | ..... |  -1   |   0   |   1   |  2    | ..... |  Ni   | Ni+1  | Ni+1  | ..... |Ni+Ng-1| Ni+Ng |
  !<     |-------|-------|-.....-|-------|-------|-------|-------|-.....-|-------|-------|-------|-.....-|-------|-------|
  !<    0-Ng                             -1      0       1       2      Ni-1     Ni                                    Ni+Ng
  !<```
  !< Where *Ni* are the finite volumes (cells) used for discretizing the domain and *Ng* are the ghost cells used for imposing the
  !< left and right boundary conditions (for a total of *2Ng* cells).
  !<
  !<#### Primitive variables organization
  !< Primitive variables are organized as an array of reals which the first index means:
  !<
  !< + 1    : density of species 1    (r1)
  !< + 2    : density of species 2    (r2)
  !< + ...  :
  !< + s    : density of species s-th (rs)
  !< + ...  :
  !< + Ns   : density of species Ns   (rNs)
  !< + Ns+1 : velocity                (u)
  !< + Ns+2 : pressure                (p)
  !< + Ns+3 : density                 (r=sum(rs))
  !< + Ns+4 : specific heats ratio    (g)
  !<
  !<#### Conservative variables organization
  !< Conservative variables are organized as an array (rank 2) of reals which the first index means:
  !<
  !< + 1    : mass conservation of species 1    (r1)
  !< + 2    : mass conservation of species 2    (r2)
  !< + ...  :
  !< + s    : mass conservation of species s-th (rs)
  !< + ...  :
  !< + Ns   : mass conservation of species Ns   (rNs)
  !< + Ns+1 : momentum conservation             (r*u)
  !< + Ns+2 : energy conservation               (r*E)
  private
  integer(I_P)                   :: ord=0     !< Space accuracy formal order.
  integer(I_P)                   :: Ni=0      !< Space dimension.
  integer(I_P)                   :: Ng=0      !< Number of ghost cells for boundary conditions handling.
  integer(I_P)                   :: Ns=0      !< Number of initial species.
  integer(I_P)                   :: Nc=0      !< Number of conservative variables, Ns+2.
  integer(I_P)                   :: Np=0      !< Number of primitive variables, Ns+4.
  real(R_P)                      :: Dx=0._R_P !< Space step.
  type(weno_interpolator_upwind) :: weno      !< WENO interpolator.
  real(R_P),    allocatable      :: U(:,:)    !< Integrand (state) variables, whole physical domain [1:Nc,1:Ni].
  real(R_P),    allocatable      :: cp0(:)    !< Specific heat cp of initial species [1:Ns].
  real(R_P),    allocatable      :: cv0(:)    !< Specific heat cv of initial species [1:Ns].
  character(:), allocatable      :: BC_L      !< Left boundary condition type.
  character(:), allocatable      :: BC_R      !< Right boundary condition type.
  integer(I_P)                   :: me=0      !< ID of this_image().
  integer(I_P)                   :: we=0      !< Number of CAF images used.
  contains
    ! auxiliary methods
    procedure, pass(self), public :: init                              !< Init field.
    procedure, pass(self), public :: destroy                           !< Destroy field.
    procedure, pass(self), public :: output                            !< Extract Euler field.
    procedure, pass(self), public :: dt => compute_dt                  !< Compute the current time step, by means of CFL condition.
    generic,               public :: assignment(=) => assign_integrand !< Overloading = assignament.
    ! private methods
    procedure, pass(self), private :: t => dEuler_dt                         !< Time derivative, residuals function.
    procedure, pass(lhs),  private :: assign_integrand => euler_assign_euler !< Euler = Euler.
    procedure, pass(self), private :: primitive2conservative                 !< Convert primitive variables to conservative ones.
    procedure, pass(self), private :: conservative2primitive                 !< Convert conservative variables to primitive ones.
    procedure, pass(self), private :: synchronize                            !< Synchronize CAF images.
    procedure, pass(self), private :: impose_boundary_conditions             !< Impose boundary conditions.
    procedure, pass(self), private :: reconstruct_interfaces_states          !< Reconstruct interfaces states.
    procedure, pass(self), private :: riemann_solver                         !< Solve the Riemann Problem at cell interfaces.
endtype euler_1D_caf_nf

type :: tvd_runge_kutta_integrator
  !< TVD RK integrator.
  !<
  !< @note The integrator must be created or initialized (initialize the RK coeficients) before used.
  integer(I_P)           :: stages=0  !< Number of stages.
  real(R_P), allocatable :: alph(:,:) !< \(\alpha\) Butcher's coefficients.
  real(R_P), allocatable :: beta(:)   !< \(\beta\) Butcher's coefficients.
  real(R_P), allocatable :: gamm(:)   !< \(\gamma\) Butcher's coefficients.
  contains
    procedure, pass(self), public :: destroy => destroy_rk     !< Destroy the integrator.
    procedure, pass(self), public :: init => init_rk           !< Initialize (create) the integrator.
    procedure, pass(self), public :: integrate => integrate_rk !< Integrate integrand field.
endtype tvd_runge_kutta_integrator

#ifdef CAF
real(R_P), allocatable :: remote_U(:,:)[:] !< CAF buffer for sharing remote conservative variables.
#else
real(R_P), allocatable :: remote_U(:,:)    !< CAF buffer for sharing remote conservative variables.
#endif
real(R_P), allocatable :: U_L(:,:)         !< Integrand (state) variables, left ghost cells [1:Nc,1:Ng].
real(R_P), allocatable :: U_R(:,:)         !< Integrand (state) variables, right ghost cells [1:Nc,Ni-Ng+1:Ni].
!-----------------------------------------------------------------------------------------------------------------------------------
contains
  ! type bound procedures of tvd_runge_kutta_integrator
  ! public methods
  elemental subroutine init_rk(self, stages)
  !---------------------------------------------------------------------------------------------------------------------------------
  !< Create the actual RK integrator: initialize the Butcher' table coefficients.
  !---------------------------------------------------------------------------------------------------------------------------------
  class(tvd_runge_kutta_integrator), intent(INOUT) :: self   !< RK integrator.
  integer(I_P),                      intent(IN)    :: stages !< Number of stages used.
  !---------------------------------------------------------------------------------------------------------------------------------

  !---------------------------------------------------------------------------------------------------------------------------------
  if (stages<1) return ! error print should be added
  self%stages = stages
  if (allocated(self%beta)) deallocate(self%beta) ; allocate(self%beta(1:stages          )) ; self%beta = 0._R_P
  if (allocated(self%alph)) deallocate(self%alph) ; allocate(self%alph(1:stages, 1:stages)) ; self%alph = 0._R_P
  if (allocated(self%gamm)) deallocate(self%gamm) ; allocate(self%gamm(          1:stages)) ; self%gamm = 0._R_P
  select case(stages)
  case(1)
    ! RK(1,1) Forward-Euler
    self%beta(1) = 1._R_P
  case(2)
    ! SSPRK(2,2)
    self%beta(1) = 0.5_R_P
    self%beta(2) = 0.5_R_P

    self%alph(2, 1) = 1._R_P

    self%gamm(2) = 1._R_P
  case(3)
    ! SSPRK(3,3)
    self%beta(1) = 1._R_P/6._R_P
    self%beta(2) = 1._R_P/6._R_P
    self%beta(3) = 2._R_P/3._R_P

    self%alph(2, 1) = 1._R_P
    self%alph(3, 1) = 0.25_R_P ; self%alph(3, 2) = 0.25_R_P

    self%gamm(2) = 1._R_P
    self%gamm(3) = 0.5_R_P
  case(5)
    ! SSPRK(5,4)
    self%beta(1) = 0.14681187618661_R_P
    self%beta(2) = 0.24848290924556_R_P
    self%beta(3) = 0.10425883036650_R_P
    self%beta(4) = 0.27443890091960_R_P
    self%beta(5) = 0.22600748319395_R_P

    self%alph(2, 1)=0.39175222700392_R_P
    self%alph(3, 1)=0.21766909633821_R_P;self%alph(3, 2)=0.36841059262959_R_P
    self%alph(4, 1)=0.08269208670950_R_P;self%alph(4, 2)=0.13995850206999_R_P;self%alph(4, 3)=0.25189177424738_R_P
    self%alph(5, 1)=0.06796628370320_R_P;self%alph(5, 2)=0.11503469844438_R_P;self%alph(5, 3)=0.20703489864929_R_P
    self%alph(5, 4)=0.54497475021237_R_P

    self%gamm(2) = 0.39175222700392_R_P
    self%gamm(3) = 0.58607968896780_R_P
    self%gamm(4) = 0.47454236302687_R_P
    self%gamm(5) = 0.93501063100924_R_P
  endselect
  return
  !---------------------------------------------------------------------------------------------------------------------------------
  endsubroutine init_rk

  elemental subroutine destroy_rk(self)
  !---------------------------------------------------------------------------------------------------------------------------------
  !< Destoy the integrator.
  !---------------------------------------------------------------------------------------------------------------------------------
  class(tvd_runge_kutta_integrator), intent(INOUT) :: self !< Integrator.
  !---------------------------------------------------------------------------------------------------------------------------------

  !---------------------------------------------------------------------------------------------------------------------------------
  self%stages = 0
  if (allocated(self%alph)) deallocate(self%alph)
  if (allocated(self%beta)) deallocate(self%beta)
  if (allocated(self%gamm)) deallocate(self%gamm)
  return
  !---------------------------------------------------------------------------------------------------------------------------------
  endsubroutine destroy_rk

  subroutine integrate_rk(self, U, stage, Dt, t)
  !---------------------------------------------------------------------------------------------------------------------------------
  !< Integrate field with explicit TVD (or SSP) Runge-Kutta scheme.
  !<
  !< @note This method can be used **after** the integrator is created (i.e. the RK coeficients are initialized).
  !---------------------------------------------------------------------------------------------------------------------------------
  class(tvd_runge_kutta_integrator), intent(IN)    :: self      !< Actual RK integrator.
  class(euler_1D_caf_nf),            intent(INOUT) :: U         !< Field to be integrated.
  class(euler_1D_caf_nf),            intent(INOUT) :: stage(1:) !< Runge-Kutta stages [1:stages].
  real(R_P),                         intent(IN)    :: Dt        !< Time step.
  real(R_P),                         intent(IN)    :: t         !< Time.
  integer(I_P)                                     :: s         !< First stages counter.
  integer(I_P)                                     :: ss        !< Second stages counter.
  !---------------------------------------------------------------------------------------------------------------------------------

  !---------------------------------------------------------------------------------------------------------------------------------
  ! computing stages
  do s=1, self%stages
    stage(s) = U
    do ss=1, s - 1
      stage(s)%U = stage(s)%U + stage(ss)%U * (Dt * self%alph(s, ss))
    enddo
    stage(s) = stage(s)%t()
  enddo
  ! computing new time step
  do s=1, self%stages
    U%U = U%U + stage(s)%U * (Dt * self%beta(s))
  enddo
  return
  !---------------------------------------------------------------------------------------------------------------------------------
  endsubroutine integrate_rk

  ! type bound procedures of euler_1D_caf_nf
  ! auxiliary methods
  subroutine init(self, Ni, Ns, Dx, BC_L, BC_R, initial_state, cp0, cv0, me, we, ord)
  !---------------------------------------------------------------------------------------------------------------------------------
  !< Init field.
  !---------------------------------------------------------------------------------------------------------------------------------
  class(euler_1D_caf_nf), intent(INOUT) :: self               !< Euler field.
  integer(I_P),           intent(IN)    :: Ni                 !< Space dimension (local image).
  integer(I_P),           intent(IN)    :: Ns                 !< Number of initial species.
  real(R_P),              intent(IN)    :: Dx                 !< Space step.
  character(*),           intent(IN)    :: BC_L               !< Left boundary condition type.
  character(*),           intent(IN)    :: BC_R               !< Right boundary condition type.
  real(R_P),              intent(IN)    :: initial_state(:,:) !< Initial state of primitive variables.
  real(R_P),              intent(IN)    :: cp0(:)             !< Initial specific heat, constant pressure.
  real(R_P),              intent(IN)    :: cv0(:)             !< Initial specific heat, constant volume.
  integer(I_P),           intent(IN)    :: me                 !< ID of this_image().
  integer(I_P),           intent(IN)    :: we                 !< Number of CAF images used.
  integer(I_P), optional, intent(IN)    :: ord                !< Space accuracy formal order.
  type(weno_factory)                    :: factory            !< WENO factory.
  class(weno_interpolator), allocatable :: weno               !< WENO interpolator.
  integer(I_P)                          :: i                  !< Space counter.
  !---------------------------------------------------------------------------------------------------------------------------------

  !---------------------------------------------------------------------------------------------------------------------------------
  self%ord = 1 ; if (present(ord)) self%ord = ord
  self%Ng = (self%ord + 1) / 2
  if (self%ord>1) then
    call factory%create(constructor=weno_constructor_upwind(S=self%Ng, eps=10._R_P**(-40)), interpolator=weno)
    self%weno = weno
  endif
  self%Ni = Ni
  self%Ns = Ns
  self%Nc = Ns + 2
  self%Np = Ns + 4
  self%Dx = Dx
  if (allocated(self%U)) deallocate(self%U) ; allocate(self%U(1:self%Nc, 1:Ni))
  self%cp0 = cp0
  self%cv0 = cv0
  self%BC_L = BC_L
  self%BC_R = BC_R
  do i=1, Ni
    self%U(:, i) = self%primitive2conservative(initial_state(:, i))
  enddo
  self%me = me
  self%we = we
#ifdef CAF
  if (allocated(remote_U)) deallocate(remote_U) ; allocate(remote_U(1:self%Nc, 1:Ni)[*])
#else
  if (allocated(remote_U)) deallocate(remote_U) ; allocate(remote_U(1:self%Nc, 1:Ni))
#endif
  if (allocated(U_L)) deallocate(U_L) ; allocate(U_L(1:self%Nc, 1:self%Ni))
  if (allocated(U_R)) deallocate(U_R) ; allocate(U_R(1:self%Nc, 1:self%Ni))
  return
  !---------------------------------------------------------------------------------------------------------------------------------
  endsubroutine init

  subroutine destroy(self)
  !---------------------------------------------------------------------------------------------------------------------------------
  !< Destroy field.
  !---------------------------------------------------------------------------------------------------------------------------------
  class(euler_1D_caf_nf), intent(INOUT) :: self !< Euler field.
  !---------------------------------------------------------------------------------------------------------------------------------

  !---------------------------------------------------------------------------------------------------------------------------------
  self%ord = 0
  self%Ni = 0
  self%Ng = 0
  self%Ns = 0
  self%Nc = 0
  self%Np = 0
  self%Dx = 0._R_P
  if (allocated(self%U)) deallocate(self%U)
  if (allocated(self%cp0)) deallocate(self%cp0)
  if (allocated(self%cv0)) deallocate(self%cv0)
  if (allocated(self%BC_L)) deallocate(self%BC_L)
  if (allocated(self%BC_R)) deallocate(self%BC_R)
  self%me = 0
  self%we = 0
  if (allocated(remote_U)) deallocate(remote_U)
  if (allocated(U_L)) deallocate(U_L)
  if (allocated(U_R)) deallocate(U_R)
  return
  !---------------------------------------------------------------------------------------------------------------------------------
  endsubroutine destroy

  pure function output(self, conservative) result(state)
  !---------------------------------------------------------------------------------------------------------------------------------
  !< Output the Euler field state (primitive variables).
  !---------------------------------------------------------------------------------------------------------------------------------
  class(euler_1D_caf_nf), intent(IN)     :: self         !< Euler field.
  logical, optional,      intent(IN)     :: conservative !< Output conservative variables instead of primitive.
  real(R_P), dimension(:,:), allocatable :: state        !< Euler state vector.
  integer(I_P)                           :: i            !< Counter.
  !---------------------------------------------------------------------------------------------------------------------------------

  !---------------------------------------------------------------------------------------------------------------------------------
  if (present(conservative)) then
    state = self%U
  else
    allocate(state(1:self%Np, 1:self%Ni))
    do i=1, self%Ni
      state(:, i) = self%conservative2primitive(self%U(:, i))
    enddo
  endif
  return
  !---------------------------------------------------------------------------------------------------------------------------------
  endfunction output

  pure function compute_dt(self, Nmax, Tmax, t, CFL) result(Dt)
  !--------------------------------------------------------------------------------------------------------------------------------
  !< Compute the current time step by means of CFL condition.
  !--------------------------------------------------------------------------------------------------------------------------------
  class(euler_1D_caf_nf), intent(IN) :: self !< Euler field.
  integer(I_P),           intent(IN) :: Nmax !< Maximun number of iterates.
  real(R_P),              intent(IN) :: Tmax !< Maximum time (ignored if Nmax>0).
  real(R_P),              intent(IN) :: t    !< Time.
  real(R_P),              intent(IN) :: CFL  !< CFL value.
  real(R_P)                          :: Dt   !< Time step.
  real(R_P), allocatable             :: P(:) !< Primitive variables.
  real(R_P)                          :: vmax !< Maximum propagation speed of signals.
  integer(I_P)                       :: i    !< Counter.
  !--------------------------------------------------------------------------------------------------------------------------------

  !--------------------------------------------------------------------------------------------------------------------------------
  associate(Ni=>self%Ni, Ns=>self%Ns, Dx=>self%Dx)
    vmax = 0._R_P
    do i=1, Ni
      P    = self%conservative2primitive(self%U(:, i))
      vmax = max(abs(P(Ns+1)) + a(p=P(Ns+2), r=P(Ns+3), g=P(Ns+4)), vmax)
    enddo
    Dt = Dx * CFL / vmax
    if (Nmax<=0) then
      if ((t + Dt) > Tmax) Dt = Tmax - t
    endif
    return
  endassociate
  !--------------------------------------------------------------------------------------------------------------------------------
  endfunction compute_dt

  ! ADT integrand deferred methods
  function dEuler_dt(self) result(dState_dt)
  !---------------------------------------------------------------------------------------------------------------------------------
  !< Time derivative of Euler field, the residuals function.
  !---------------------------------------------------------------------------------------------------------------------------------
  class(euler_1D_caf_nf), intent(IN) :: self      !< Euler field.
  type(euler_1D_caf_nf)              :: dState_dt !< Euler field time derivative.
  real(R_P), allocatable             :: F(:,:)    !< Fluxes of conservative variables.
  real(R_P), allocatable             :: P(:,:)    !< Primitive variables.
  real(R_P), allocatable             :: PR(:,:,:) !< Left (1) and right (2) (reconstructed) interface values of primitive variables.
  integer(I_P)                       :: i         !< Counter.
  !---------------------------------------------------------------------------------------------------------------------------------

  !---------------------------------------------------------------------------------------------------------------------------------
  allocate(F(1:self%Nc, 0:self%Ni))
  do i=0, self%Ni
    F(:, i) = 0._R_P
  enddo
  allocate(P(1:self%Np, 1-self%Ng:self%Ni+self%Ng))
  do i=1-self%Ng, self%Ni+self%Ng
    P(:, i) = 0._R_P
  enddo
  allocate(PR(1:self%Np, 1:2, 0:self%Ni+1))
  do i=0, self%Ni+1
    PR(:, :, i) = 0._R_P
  enddo
  ! compute primitive variables
  do i=1, self%Ni
    P(:, i) = self%conservative2primitive(self%U(:, i))
  enddo
  call self%impose_boundary_conditions(primitive=P)
  call self%reconstruct_interfaces_states(primitive=P, r_primitive=PR)
  ! compute fluxes by solving Rimeann Problems at each interface
  do i=0, self%Ni
    call self%riemann_solver(r1=PR(self%Ns+3, 2, i  ), &
                             u1=PR(self%Ns+1, 2, i  ), &
                             p1=PR(self%Ns+2, 2, i  ), &
                             g1=PR(self%Ns+4, 2, i  ), &
                             r4=PR(self%Ns+3, 1, i+1), &
                             u4=PR(self%Ns+1, 1, i+1), &
                             p4=PR(self%Ns+2, 1, i+1), &
                             g4=PR(self%Ns+4, 1, i+1), &
                             F=F(:, i))
    if (self%Ns>1) then
      if (F(1, i)>0._R_P) then
        F(1:self%Ns, i) = PR(1:self%Ns, 2, i  )/PR(self%Ns+3, 2, i  )*F(1, i)
      else
        F(1:self%Ns, i) = PR(1:self%Ns, 1, i+1)/PR(self%Ns+3, 1, i+1)*F(1, i)
      endif
    endif
  enddo
  ! compute residuals
  dState_dt = self
  do i=1, self%Ni
    dState_dt%U(:, i) = (F(:, i - 1) - F(:, i)) / self%Dx
  enddo
  return
  !---------------------------------------------------------------------------------------------------------------------------------
  endfunction dEuler_dt

  subroutine euler_assign_euler(lhs, rhs)
  !---------------------------------------------------------------------------------------------------------------------------------
  !< Assign one Euler field to another.
  !---------------------------------------------------------------------------------------------------------------------------------
  class(euler_1D_caf_nf), intent(INOUT) :: lhs !< Left hand side.
  class(euler_1D_caf_nf), intent(IN)    :: rhs !< Right hand side.
  !---------------------------------------------------------------------------------------------------------------------------------

  !---------------------------------------------------------------------------------------------------------------------------------
  select type(rhs)
  class is(euler_1D_caf_nf)
                             lhs%ord  = rhs%ord
                             lhs%Ni   = rhs%Ni
                             lhs%Ng   = rhs%Ng
                             lhs%Ns   = rhs%Ns
                             lhs%Nc   = rhs%Nc
                             lhs%Np   = rhs%Np
                             lhs%Dx   = rhs%Dx
                             lhs%weno = rhs%weno
    if (allocated(rhs%U))    lhs%U    = rhs%U
    if (allocated(rhs%cp0))  lhs%cp0  = rhs%cp0
    if (allocated(rhs%cv0))  lhs%cv0  = rhs%cv0
    if (allocated(rhs%BC_L)) lhs%BC_L = rhs%BC_L
    if (allocated(rhs%BC_R)) lhs%BC_R = rhs%BC_R
                             lhs%me   = rhs%me
                             lhs%we   = rhs%we
  endselect
  return
  !---------------------------------------------------------------------------------------------------------------------------------
  endsubroutine euler_assign_euler

  pure function primitive2conservative(self, primitive) result(conservative)
  !---------------------------------------------------------------------------------------------------------------------------------
  !< Convert primitive variables to conservative variables.
  !---------------------------------------------------------------------------------------------------------------------------------
  class(euler_1D_caf_nf), intent(IN) :: self                    !< Euler field.
  real(R_P),              intent(IN) :: primitive(:)            !< Primitive variables.
  real(R_P)                          :: conservative(1:self%Nc) !< Conservative variables.
  !---------------------------------------------------------------------------------------------------------------------------------

  !---------------------------------------------------------------------------------------------------------------------------------
  associate(Ns=>self%Ns)
    conservative(1:Ns) = primitive(1:Ns)
    conservative(Ns + 1) = primitive(Ns + 3) * primitive(Ns + 1)
    conservative(Ns + 2) = primitive(Ns + 2) / (primitive(Ns + 4) - 1._R_P) + &
                                0.5_R_P*primitive(Ns + 3) * primitive(Ns + 1) * primitive(Ns + 1)
  endassociate
  return
  !---------------------------------------------------------------------------------------------------------------------------------
  endfunction primitive2conservative

  pure function conservative2primitive(self, conservative) result(primitive)
  !--------------------------------------------------------------------------------------------------------------------------------
  !< Convert conservative variables to primitive variables.
  !--------------------------------------------------------------------------------------------------------------------------------
  class(euler_1D_caf_nf), intent(IN) :: self                 !< Euler field.
  real(R_P),              intent(IN) :: conservative(:)      !< Conservative variables.
  real(R_P)                          :: primitive(1:self%Np) !< Primitive variables.
  real(R_P), allocatable             :: c(:)                 !< Species concentration.
  !--------------------------------------------------------------------------------------------------------------------------------

  !--------------------------------------------------------------------------------------------------------------------------------
  associate(Ns=>self%Ns, cp0=>self%cp0, cv0=>self%cv0)
    primitive(1:Ns) = conservative(1:Ns)
    primitive(Ns + 3) = sum(conservative(1:Ns))
    c = primitive(1:Ns) / primitive(Ns + 3)
    primitive(Ns + 4) = dot_product(c, cp0) / dot_product(c, cv0)
    primitive(Ns + 1) = conservative(Ns + 1) / primitive(Ns + 3)
    primitive(Ns + 2) = (conservative(Ns + 2) - 0.5_R_P * primitive(Ns + 3) * primitive(Ns + 1) * primitive(Ns + 1)) * &
                        (primitive(Ns + 4) - 1._R_P)
  endassociate
  return
  !--------------------------------------------------------------------------------------------------------------------------------
  endfunction conservative2primitive

  subroutine synchronize(self)
  !---------------------------------------------------------------------------------------------------------------------------------
  !< Synchronize CAF images.
  !---------------------------------------------------------------------------------------------------------------------------------
  class(euler_1D_caf_nf), intent(IN) :: self !< Euler field.
  integer(I_P)                       :: i    !< Images counter.
  !---------------------------------------------------------------------------------------------------------------------------------

  !---------------------------------------------------------------------------------------------------------------------------------
#ifdef CAF
  if (self%we>1) then
    remote_U = self%U
    if (self%me==1) then
      sync images(self%me+1)
      U_R(:,:) = remote_U(:,:)[self%me+1]
    else if (self%me==self%we) then
      sync images(self%me-1)
      U_L(:,:) = remote_U(:,:)[self%me-1]
    else
      sync images([self%me-1, self%me+1])
      U_L(:,:) = remote_U(:,:)[self%me-1]
      U_R(:,:) = remote_U(:,:)[self%me+1]
    endif
  endif
#endif
  return
  !---------------------------------------------------------------------------------------------------------------------------------
  endsubroutine synchronize

  subroutine impose_boundary_conditions(self, primitive)
  !--------------------------------------------------------------------------------------------------------------------------------
  !< Impose boundary conditions.
  !<
  !< The boundary conditions are imposed on the primitive variables by means of the ghost cells approach.
  !--------------------------------------------------------------------------------------------------------------------------------
  class(euler_1D_caf_nf), intent(IN)    :: self                                           !< Euler field.
  real(R_P),              intent(INOUT) :: primitive(1:self%Np,1-self%Ng:self%Ni+self%Ng) !< Primitive variables [1:Np,1-Ng:Ni+Ng].
  integer(I_P)                          :: i                                              !< Space counter.
  character(len=:), allocatable         :: bc_type                                        !< String containing BC type.
  !--------------------------------------------------------------------------------------------------------------------------------

  !--------------------------------------------------------------------------------------------------------------------------------
  call self%synchronize
  bc_type = trim(adjustl(self%BC_L))
  if ('CON' == bc_type(1:3)) then ! connection between remote images
    do i=1-self%Ng, 0
      primitive(:, i) = self%conservative2primitive(U_L(:, self%Ni+i))
    enddo
  else
    select case(bc_type(1:3))
      case('TRA') ! trasmissive (non reflective) BC
        do i=1-self%Ng, 0
          primitive(:, i) = primitive(:, -i+1)
        enddo
      case('REF') ! reflective BC
        do i=1-self%Ng, 0
          primitive(:,           i) =  primitive(:,           -i+1) ! all variables
          primitive(self%Ns + 1, i) = -primitive(self%Ns + 1, -i+1) ! only velocity
        enddo
    endselect
  endif

  bc_type = trim(adjustl(self%BC_R))
  if ('CON' == bc_type(1:3)) then ! connection between remote images
    do i=self%Ni+1, self%Ni+self%Ng
      primitive(:, i) = self%conservative2primitive(U_R(:, i-self%Ni))
    enddo
  else
    select case(bc_type(1:3))
      case('TRA') ! trasmissive (non reflective) BC
        do i=self%Ni+1, self%Ni+self%Ng
          primitive(:, i) = primitive(:, self%Ni-(i-self%Ni-1))
        enddo
      case('REF') ! reflective BC
        do i=self%Ni+1, self%Ni+self%Ng
          primitive(:,           i) =  primitive(:,           self%Ni-(i-self%Ni-1)) ! all variables
          primitive(self%Ns + 1, i) = -primitive(self%Ns + 1, self%Ni-(i-self%Ni-1)) ! only velocity
        enddo
    endselect
  endif
  return
  !--------------------------------------------------------------------------------------------------------------------------------
  endsubroutine impose_boundary_conditions

  subroutine reconstruct_interfaces_states(self, primitive, r_primitive)
  !--------------------------------------------------------------------------------------------------------------------------------
  !< Reconstruct the interfaces states (into primitive variables formulation) by the requested order of accuracy.
  !--------------------------------------------------------------------------------------------------------------------------------
  class(euler_1D_caf_nf), intent(IN)    :: self                                            !< Euler field.
  real(R_P),              intent(IN)    :: primitive(1:self%Np, 1-self%Ng:self%Ni+self%Ng) !< Primitive variables.
  real(R_P),              intent(INOUT) :: r_primitive(1:self%Np, 1:2, 0:self%Ni+1)        !< Reconstructed primitive variables.
  real(R_P)                             :: C(1:2, 1-self%Ng:-1+self%Ng, 1:self%Ns+2)       !< Pseudo characteristic variables.
  real(R_P)                             :: CR(1:self%Ns+2, 1:2)                            !< Pseudo characteristic reconst. vars.
  real(R_P)                             :: Pm(1:self%Np, 1:2)                              !< Mean of primitive variables.
  real(R_P)                             :: LPm(1:self%Ns+2, 1:self%Ns+2, 1:2)              !< Mean left eigenvectors matrix.
  real(R_P)                             :: RPm(1:self%Ns+2, 1:self%Ns+2, 1:2)              !< Mean right eigenvectors matrix.
  integer(I_P)                          :: i                                               !< Counter.
  integer(I_P)                          :: j                                               !< Counter.
  integer(I_P)                          :: f                                               !< Counter.
  integer(I_P)                          :: v                                               !< Counter.
  !--------------------------------------------------------------------------------------------------------------------------------

  !--------------------------------------------------------------------------------------------------------------------------------
  select case(self%ord)
  case(1) ! 1st order piecewise constant reconstruction
    do i=0, self%Ni+1
      r_primitive(:, 1, i) = primitive(:, i)
      r_primitive(:, 2, i) = r_primitive(:, 1, i)
    enddo
  case(3, 5, 7) ! 3rd, 5th or 7th order WENO reconstruction
    do i=0, self%Ni+1
      ! trasform primitive variables to pseudo charteristic ones
      do f=1, 2
        Pm(:,f) = 0.5_R_P * (primitive(:, i+f-2) + primitive(:, i+f-1))
      enddo
      do f=1, 2
        LPm(:, :, f) = eigen_vect_L(Ns=self%Ns, Np=self%Np, primitive=Pm(:, f))
        RPm(:, :, f) = eigen_vect_R(Ns=self%Ns, Np=self%Np, primitive=Pm(:, f))
      enddo
      do j=i+1-self%Ng, i-1+self%Ng
        do f=1, 2
          do v=1, self%Ns+2
            C(f, j-i, v) = dot_product(LPm(v, 1:self%Ns+2, f), primitive(1:self%Ns+2, j))
          enddo
        enddo
      enddo
      ! compute WENO reconstruction of pseudo charteristic variables
      do v=1, self%Ns+2
        call self%weno%interpolate(S=self%Ng,                               &
                                   stencil=C(1:2, 1-self%Ng:-1+self%Ng, v), &
                                   location='both',                         &
                                   interpolation=CR(v, 1:2))
      enddo
      ! trasform back reconstructed pseudo charteristic variables to primitive ones
      do f=1, 2
        do v=1, self%Ns+2
          r_primitive(v, f, i) = dot_product(RPm(v, 1:self%Ns+2, f), CR(1:self%Ns+2, f))
        enddo
        r_primitive(self%Ns+3, f, i) = sum(r_primitive(1:self%Ns, f, i))
        r_primitive(self%Ns+4, f, i) = dot_product(r_primitive(1:self%Ns, f, i) / r_primitive(self%Ns+3, f, i), self%cp0) / &
                                       dot_product(r_primitive(1:self%Ns, f, i) / r_primitive(self%Ns+3, f, i), self%cv0)
      enddo
    enddo
  endselect
  return
  !--------------------------------------------------------------------------------------------------------------------------------
  contains
    pure function eigen_vect_L(Ns, Np, primitive) result(L)
    !-------------------------------------------------------------------------------------------------------------------------------
    !< Compute left eigenvectors from primitive variables.
    !-------------------------------------------------------------------------------------------------------------------------------
    integer(I_P), intent(IN) :: Ns               !< Number of initial species.
    integer(I_P), intent(IN) :: Np               !< Number of primitive variables.
    real(R_P),    intent(IN) :: primitive(1:Np)  !< Primitive variables.
    real(R_P)                :: L(1:Ns+2,1:Ns+2) !< Left eigenvectors matrix.
    real(R_P)                :: gp               !< g*p.
    real(R_P)                :: gp_a             !< g*p/a.
    integer(I_P)             :: i                !< Counter.
    integer(I_P)             :: s                !< Counter.
    !-------------------------------------------------------------------------------------------------------------------------------

    !-------------------------------------------------------------------------------------------------------------------------------
    gp   = primitive(Ns+4) * primitive(Ns+2)
    gp_a = gp/a(p=primitive(Ns+2), r=primitive(Ns+3), g=primitive(Ns+4))
    L = 0._R_P
                            L(1,    Ns+1) = -gp_a              ; L(1,    Ns+2) =  1._R_P
    do s=2, Ns+1
      if (primitive(s-1)>0) L(s,    s-1 ) =  gp/primitive(s-1) ; L(s,    Ns+2) = -1._R_P
    enddo
                            L(Ns+2, Ns+1) =  gp_a              ; L(Ns+2, Ns+2) =  1._R_P
    return
    !-------------------------------------------------------------------------------------------------------------------------------
    endfunction eigen_vect_L

    pure function eigen_vect_R(Ns, Np, primitive) result(R)
    !-------------------------------------------------------------------------------------------------------------------------------
    !< Compute right eigenvectors from primitive variables.
    !-------------------------------------------------------------------------------------------------------------------------------
    integer(I_P), intent(IN) :: Ns               !< Number of initial species.
    integer(I_P), intent(IN) :: Np               !< Number of primitive variables.
    real(R_P),    intent(IN) :: primitive(1:Np)  !< Primitive variables.
    real(R_P)                :: R(1:Ns+2,1:Ns+2) !< Right eigenvectors matrix.
    real(R_P)                :: gp               !< g*p.
    real(R_P)                :: ss               !< Speed of sound, sqrt(g*p/r).
    real(R_P)                :: gp_inv           !< 1/(g*p).
    integer(I_P)             :: i                !< Counter.
    integer(I_P)             :: s                !< Counter.
    !-------------------------------------------------------------------------------------------------------------------------------

    !-------------------------------------------------------------------------------------------------------------------------------
    gp = primitive(Ns+4) * primitive(Ns+2)
    ss = a(p=primitive(Ns+2), r=primitive(Ns+3), g=primitive(Ns+4))
    gp_inv = 1._R_P/gp
    R = 0._R_P
    do s=1, Ns
      R(s,    1) =  0.5_R_P*primitive(s) * gp_inv ; R(s, s+1) = primitive(s) * gp_inv ; R(s,    Ns+2) = R(s, 1)
    enddo
      R(Ns+1, 1) = -0.5_R_P* ss *gp_inv           ;                                     R(Ns+1, Ns+2) = 0.5_R_P* ss * gp_inv
      R(Ns+2, 1) =  0.5_R_P                       ;                                     R(Ns+2, Ns+2) = 0.5_R_P
    return
    !-------------------------------------------------------------------------------------------------------------------------------
    endfunction eigen_vect_R
  endsubroutine reconstruct_interfaces_states

  pure subroutine riemann_solver(self, p1, r1, u1, g1, p4, r4, u4, g4, F)
  !---------------------------------------------------------------------------------------------------------------------------------
  !< Solve the Riemann problem between the state $1$ and $4$ using the (local) Lax Friedrichs (Rusanov) solver.
  !---------------------------------------------------------------------------------------------------------------------------------
  class(euler_1D_caf_nf), intent(IN)  :: self         !< Euler field.
  real(R_P),              intent(IN)  :: p1           !< Pressure of state 1.
  real(R_P),              intent(IN)  :: r1           !< Density of state 1.
  real(R_P),              intent(IN)  :: u1           !< Velocity of state 1.
  real(R_P),              intent(IN)  :: g1           !< Specific heats ratio of state 1.
  real(R_P),              intent(IN)  :: p4           !< Pressure of state 4.
  real(R_P),              intent(IN)  :: r4           !< Density of state 4.
  real(R_P),              intent(IN)  :: u4           !< Velocity of state 4.
  real(R_P),              intent(IN)  :: g4           !< Specific heats ratio of state 4.
  real(R_P),              intent(OUT) :: F(1:self%Nc) !< Resulting fluxes.
  real(R_P)                           :: F1(1:3)      !< State 1 fluxes.
  real(R_P)                           :: F4(1:3)      !< State 4 fluxes.
  real(R_P)                           :: u            !< Velocity of the intermediate states.
  real(R_P)                           :: p            !< Pressure of the intermediate states.
  real(R_P)                           :: S1           !< Maximum wave speed of state 1 and 4.
  real(R_P)                           :: S4           !< Maximum wave speed of state 1 and 4.
  real(R_P)                           :: lmax         !< Maximum wave speed estimation.
  !---------------------------------------------------------------------------------------------------------------------------------

  !---------------------------------------------------------------------------------------------------------------------------------
  ! evaluating the intermediates states 2 and 3 from the known states U1,U4 using the PVRS approximation
  call compute_inter_states(p1 = p1, r1 = r1, u1 = u1, g1 = g1, p4 = p4, r4 = r4, u4 = u4, g4 = g4, p = p, S = u, S1 = S1, S4 = S4)
  ! evalutaing the maximum waves speed
  lmax = max(abs(S1), abs(u), abs(S4))
  ! computing the fluxes of state 1 and 4
  F1 = fluxes(p = p1, r = r1, u = u1, g = g1)
  F4 = fluxes(p = p4, r = r4, u = u4, g = g4)
  ! computing the Lax-Friedrichs fluxes approximation
  F(1)         = 0.5_R_P*(F1(1) + F4(1) - lmax*(r4                        - r1                       ))
  F(self%Ns+1) = 0.5_R_P*(F1(2) + F4(2) - lmax*(r4*u4                     - r1*u1                    ))
  F(self%Ns+2) = 0.5_R_P*(F1(3) + F4(3) - lmax*(r4*E(p=p4,r=r4,u=u4,g=g4) - r1*E(p=p1,r=r1,u=u1,g=g1)))
  return
  !---------------------------------------------------------------------------------------------------------------------------------
  contains
    pure function fluxes(p, r, u, g) result(Fc)
    !-------------------------------------------------------------------------------------------------------------------------------
    !< 1D Euler fluxes from primitive variables.
    !-------------------------------------------------------------------------------------------------------------------------------
    real(R_P), intent(IN) :: p       !< Pressure.
    real(R_P), intent(IN) :: r       !< Density.
    real(R_P), intent(IN) :: u       !< Velocity.
    real(R_P), intent(IN) :: g       !< Specific heats ratio.
    real(R_P)             :: Fc(1:3) !< State fluxes.
    !-------------------------------------------------------------------------------------------------------------------------------

    !-------------------------------------------------------------------------------------------------------------------------------
    Fc(1) = r*u
    Fc(2) = Fc(1)*u + p
    Fc(3) = Fc(1)*H(p=p, r=r, u=u, g=g)
    return
    !-------------------------------------------------------------------------------------------------------------------------------
    endfunction fluxes
  endsubroutine riemann_solver

  ! non type-bound procedures
  pure subroutine compute_inter_states(r1, p1, u1, g1, r4, p4, u4, g4, p, S, S1, S4)
  !------------------------------------------------------------------------------------------------------------------------------
  !< Compute inter states (23*-states) from state1 and state4.
  !------------------------------------------------------------------------------------------------------------------------------
  real(R_P), intent(IN)  :: r1             !< Density of state 1.
  real(R_P), intent(IN)  :: p1             !< Pressure of state 1.
  real(R_P), intent(IN)  :: u1             !< Velocity of state 1.
  real(R_P), intent(IN)  :: g1             !< Specific heat ratio of state 1.
  real(R_P), intent(IN)  :: r4             !< Density of state 4.
  real(R_P), intent(IN)  :: p4             !< Pressure of state 4.
  real(R_P), intent(IN)  :: u4             !< Velocity of state 4.
  real(R_P), intent(IN)  :: g4             !< Specific heat ratio of state 4.
  real(R_P), intent(OUT) :: p              !< Pressure of the intermediate states.
  real(R_P), intent(OUT) :: S              !< Contact discontinuity signal velocity.
  real(R_P), intent(OUT) :: S1             !< Left fastest signal velocity.
  real(R_P), intent(OUT) :: S4             !< Right fastest signal velocity.
  real(R_P)              :: a1             !< Speed of sound of state 1.
  real(R_P)              :: a4             !< Speed of sound of state 4.
  real(R_P)              :: ram            !< Mean value of rho*a.
  real(R_P), parameter   :: toll=1e-10_R_P !< Tollerance.
  !------------------------------------------------------------------------------------------------------------------------------

  !------------------------------------------------------------------------------------------------------------------------------
  ! evaluation of the intermediate states pressure and velocity
  a1  = sqrt(g1 * p1 / r1)                              ! left speed of sound
  a4  = sqrt(g4 * p4 / r4)                              ! right speed of sound
  ram = 0.5_R_P * (r1 + r4) * 0.5_R_P * (a1 + a4)       ! product of mean density for mean speed of sound
  S   = 0.5_R_P * (u1 + u4) - 0.5_R_P * (p4 - p1) / ram ! evaluation of the contact wave speed (velocity of intermediate states)
  p   = 0.5_R_P * (p1 + p4) - 0.5_R_P * (u4 - u1) * ram ! evaluation of the pressure of the intermediate states
  ! evaluation of the left wave speeds
  if (p<=p1*(1._R_P + toll)) then
    ! rarefaction
    S1 = u1 - a1
  else
    ! shock
    S1 = u1 - a1 * sqrt(1._R_P + (g1 + 1._R_P) / (2._R_P * g1) * (p / p1 - 1._R_P))
  endif
  ! evaluation of the right wave speeds
  if (p<=p4 * (1._R_P + toll)) then
    ! rarefaction
    S4 = u4 + a4
  else
    ! shock
    S4 = u4 + a4 * sqrt(1._R_P + (g4 + 1._R_P) / (2._R_P * g4) * ( p / p4 - 1._R_P))
  endif
  return
  !------------------------------------------------------------------------------------------------------------------------------
  endsubroutine compute_inter_states

  elemental function p(r, a, g) result(pressure)
  !---------------------------------------------------------------------------------------------------------------------------------
  !< Compute the pressure for an ideal calorically perfect gas.
  !---------------------------------------------------------------------------------------------------------------------------------
  real(R_P), intent(IN) :: r        !< Density.
  real(R_P), intent(IN) :: a        !< Speed of sound.
  real(R_P), intent(IN) :: g        !< Specific heats ratio \(\frac{{c_p}}{{c_v}}\).
  real(R_P)             :: pressure !< Pressure.
  !---------------------------------------------------------------------------------------------------------------------------------

  !---------------------------------------------------------------------------------------------------------------------------------
  pressure = r*a*a/g
  return
  !---------------------------------------------------------------------------------------------------------------------------------
  endfunction p

  elemental function r(p, a, g) result(density)
  !---------------------------------------------------------------------------------------------------------------------------------
  !< Compute the density for an ideal calorically perfect gas.
  !---------------------------------------------------------------------------------------------------------------------------------
  real(R_P), intent(IN) :: p       !< Pressure.
  real(R_P), intent(IN) :: a       !< Speed of sound.
  real(R_P), intent(IN) :: g       !< Specific heats ratio \(\frac{{c_p}}{{c_v}}\).
  real(R_P)             :: density !< Density.
  !---------------------------------------------------------------------------------------------------------------------------------

  !---------------------------------------------------------------------------------------------------------------------------------
  density = g*p/(a*a)
  return
  !---------------------------------------------------------------------------------------------------------------------------------
  endfunction r

  elemental function a(p, r, g) result(ss)
  !---------------------------------------------------------------------------------------------------------------------------------
  !< Compute the speed of sound for an ideal calorically perfect gas.
  !---------------------------------------------------------------------------------------------------------------------------------

  !---------------------------------------------------------------------------------------------------------------------------------
  real(R_P), intent(IN) :: p  !< Pressure.
  real(R_P), intent(IN) :: r  !< Density.
  real(R_P), intent(IN) :: g  !< Specific heats ratio \(\frac{{c_p}}{{c_v}}\).
  real(R_P)             :: ss !< Speed of sound.
  !---------------------------------------------------------------------------------------------------------------------------------

  !---------------------------------------------------------------------------------------------------------------------------------
  ss = sqrt(g*p/r)
  return
  !---------------------------------------------------------------------------------------------------------------------------------
  endfunction a

  elemental function E(p, r, u, g) result(energy)
  !---------------------------------------------------------------------------------------------------------------------------------
  !< Compute total specific energy (per unit of mass).
  !<$$
  !<  E = \frac{p}{{\left( {\g  - 1} \right)\r }} + \frac{{u^2 }}{2}
  !<$$
  !---------------------------------------------------------------------------------------------------------------------------------
  real(R_P), intent(IN) :: p      !< Pressure.
  real(R_P), intent(IN) :: r      !< Density.
  real(R_P), intent(IN) :: u      !< Module of velocity vector.
  real(R_P), intent(IN) :: g      !< Specific heats ratio \(\frac{{c_p}}{{c_v}}\).
  real(R_P)             :: energy !< Total specific energy (per unit of mass).
  !---------------------------------------------------------------------------------------------------------------------------------

  !---------------------------------------------------------------------------------------------------------------------------------
  energy = p/((g - 1._R_P) * r) + 0.5_R_P * u * u
  return
  !---------------------------------------------------------------------------------------------------------------------------------
  endfunction E

  elemental function H(p, r, u, g) result(entalpy)
  !---------------------------------------------------------------------------------------------------------------------------------
  !< Compute total specific entalpy (per unit of mass).
  !<$$
  !<  H = \frac{{\g p}}{{\left( {\g  - 1} \right)\r }} + \frac{{u^2 }}{2}
  !<$$
  !---------------------------------------------------------------------------------------------------------------------------------
  real(R_P), intent(IN) :: g       !< Specific heats ratio \(\frac{{c_p}}{{c_v}}\).
  real(R_P), intent(IN) :: p       !< Pressure.
  real(R_P), intent(IN) :: r       !< Density.
  real(R_P), intent(IN) :: u       !< Module of velocity vector.
  real(R_P)             :: entalpy !< Total specific entalpy (per unit of mass).
  !---------------------------------------------------------------------------------------------------------------------------------

  !---------------------------------------------------------------------------------------------------------------------------------
  entalpy = g * p / ((g - 1._R_P) * r) + 0.5_R_P * u * u
  return
  !---------------------------------------------------------------------------------------------------------------------------------
  endfunction H
endmodule type_euler_1D_caf_no_foodie
