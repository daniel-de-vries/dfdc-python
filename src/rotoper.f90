!=========================================================================
! DFDC (Ducted Fan Design Code) is an aerodynamic and aeroacoustic design
! and analysis tool for aircraft with propulsors in ducted fan
! configurations.
! 
! This software was developed under the auspices and sponsorship of the
! Tactical Technology Office (TTO) of the Defense Advanced Research
! Projects Agency (DARPA).
! 
! Copyright (c) 2004, 2005, Booz Allen Hamilton Inc., All Rights Reserved
!
! This program is free software; you can redistribute it and/or modify it
! under the terms of the GNU General Public License as published by the
! Free Software Foundation; either version 2 of the License, or (at your
! option) any later version.
! 
! This program is distributed in the hope that it will be useful, but
! WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
! General Public License for more details.
! 
! You should have received a copy of the GNU General Public License along
! with this program; if not, write to the Free Software Foundation, Inc.,
! 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
!
! Authors: Harold Youngren (guppy@maine.rr.com), Mark Drela (drela@mit.edu)
! Program Management: Brad Tousley, Paul Eremenko (eremenko@alum.mit.edu)
!
!
!=========================================================================
!
!     Version 070-ES1
!     Philip Carter, Esotec Developments, February 2009
!     philip (at) esotec (dot) org
!
!     Changes from 0.70:
!
!     Alpha stored in ALPHAR whenever airfoil data is called.
!     Alpha and CDR zeroed for final station, tip gap cases.
!     SHOWDUCT, SHOWACTDISK, SHOWBLADE...: argument (LU), formats tweaked.
!
!     ROTRPRT: Alpha listing added, formats tweaked. 
!     Beta and Alpha listed in local coords if LCOORD is TRUE and RPM.LE.0. 
!     Global/local message added to output for rotors of RPM.LE.0.
!
!     Version 070-ES1a  4 March 2009
!
!     ROTRPRT: CP and CT output fixed for neg-rpm disks
!     Local alfa output bug fixed for neg rpm and tip gap
!
!=========================================================================


SUBROUTINE ROTINITTHR(THR)
    !----------------------------------------------------------------
    !     Initialize rotor velocities with estimate of
    !     blade circulation and induced velocites derived from thrust
    !
    !     Assumes momentum theory for axial flow calculation
    !----------------------------------------------------------------
    INCLUDE 'DFDC.INC'
    !
    !---- Assume that rotor/act. disk is first disk
    NR = 1
    !---- Initialize rotor with constant circulation derived from thrust
    THRUST = THR
    BGAMA = 2.0 * PI * THRUST / (RHO * ADISK(NR) * OMEGA(NR))
    IF(LDBG) WRITE(LUNDBG, *) 'ROTINITTHR  THRUST  BGAMA ', THRUST, BGAMA
    !---- Induced velocity from momentum theory
    VHSQ = 2.0 * THRUST / (RHO * ADISK(NR))
    VAIND = -0.5 * QINF + SQRT((0.5 * QINF)**2 + VHSQ)
    !---- Set average velocity in duct
    VAVGINIT = VAIND + QINF
    !---- Set blade circulation
    DO IR = 1, NRC
        BGAM(IR, NR) = BGAMA
    END DO
    IF(TGAP.GT.0.0) BGAM(NRC, NR) = 0.0
    !---- Initialize using our circulation estimate
    CALL ROTINITBGAM
    !
    IF(LDBG) THEN
        WRITE(LUNDBG, *) 'ROTINITTHR'
        WRITE(LUNDBG, *) ' Setting circulation from THRUST= ', THRUST
        WRITE(LUNDBG, *) ' Average circulation       B*GAM= ', BGAMA
        WRITE(LUNDBG, *) ' Average axial velocity    VAavg= ', VAVGINIT
    ENDIF
    !
    RETURN
END
! ROTINITTHR



SUBROUTINE ROTINITBGAM
    !----------------------------------------------------------------
    !     Initialize rotor velocities using current blade circulation
    !     Sets approximate axial induced velocites from thrust
    !
    !     Assumes momentum theory for axial flow calculation
    !----------------------------------------------------------------
    INCLUDE 'DFDC.inc'
    !
    IF(LDBG) WRITE(*, *) 'Initializing rotor GAM and induced vel.'
    !
    !---- Find area averaged B*GAMMA for rotor(s) to estimate thrust
    THRUST = 0.0
    DO NR = 1, NROTOR
        ABGAM = 0.0
        AREA = 0.0
        DO IR = 1, NRC
            DA = PI * (YRP(IR + 1, NR)**2 - YRP(IR, NR)**2)
            AREA = AREA + DA
            ABGAM = ABGAM + DA * BGAM(IR, NR)
        END DO
        BGAMA = ABGAM / AREA
        THRUST = THRUST + ADISK(NR) * RHO * OMEGA(NR) * BGAMA * PI2I
    END DO
    !
    !     Thrust used for estimates for slipstream axial velocities
    IF(LDBG) WRITE(*, *) 'Est. rotor thrust (from B*GAM) = ', THRUST
    !---- Induced velocity from momentum theory
    VHSQ = 2.0 * THRUST / (RHO * ADISK(1))
    VAIND = -0.5 * QINF + SQRT((0.5 * QINF)**2 + VHSQ)
    !---- Set average velocity in duct
    VAVGINIT = VAIND + QINF
    !c    VAVGINIT = SQRT(THRUST/(RHO*ADISK(1)))  ! old definition
    !
    IF(LDBG) THEN
        WRITE(LUNDBG, *) 'ROTINITBGAM'
        WRITE(LUNDBG, *) ' Average circulation       B*GAM= ', BGAMA
        WRITE(LUNDBG, *) ' Estimated                THRUST= ', THRUST
        WRITE(LUNDBG, *) ' Average axial velocity    VAavg= ', VAVGINIT
    ENDIF
    !
    DO NR = 1, NROTOR
        DO IR = 1, NRC
            !---- Absolute frame induced velocities
            VIND(1, IR, NR) = VAIND
            VIND(2, IR, NR) = 0.0
            VIND(3, IR, NR) = BGAM(IR, NR) * PI2I / YRC(IR, NR)
        END DO
    END DO
    CALL SETROTVEL
    LVMAV = .FALSE.
    !c      CALL VMAVGINIT(VAVGINIT)
    !
    IF(LDBG) THEN
        NR = 1
        WRITE(*, 1400) NR
        DO IR = 1, NRC
            WX = VREL(1, IR, NR)
            WR = VREL(2, IR, NR)
            WT = VREL(3, IR, NR)
            WM = SQRT(WX * WX + WR * WR)
            IF(WT.NE.0.0) THEN
                PHIR = ATAN2(WM, -WT)
            ELSE
                PHIR = 0.5 * PI
            ENDIF
            WRITE(*, 1401) YRC(IR, NR), WX, WR, WM, WT, PHIR / DTR, BGAM(IR, NR)
        END DO
    ENDIF
    !
    1400 FORMAT(/'Blade velocities initialized on blade row ', I3&
            /'     r          Wx         Wr         Wm', &
            '         Wt        Phi       BGam')
    1401 FORMAT(1X, 8G11.4)
    !
    RETURN
END
! ROTINITBGAM



SUBROUTINE ROTINITBLD
    INCLUDE 'DFDC.inc'
    !---------------------------------------------------------
    !     Sets reasonable initial circulation using current
    !     rotor blade geometry (chord, beta).
    !
    !     Initial circulations are set w/o induced effects
    !     An iteration is done using the self-induced velocity
    !     from momentum theory to converge an approximate
    !     induced axial velocity
    !----------------------------------------------------------
    !
    DATA NITERG / 10 /
    !
    !---- Set up to accumulate blade/disk circulations
    CALL CLRGRDFLW
    !
    !---- This initialization assumes blade disks are in streamwise order <- FIX THIS!
    DO NR = 1, NROTOR
        !
        IF(IRTYPE(NR).EQ.1) THEN
            CALL ROTBG2GRD(NR)
            !
        ELSEIF(IRTYPE(NR).EQ.2) THEN
            IG = IGROTOR(NR)
            !
            !---- Initialize section circulation neglecting induced swirl velocity
            !---- Start with no circulation and current axial flow estimate
            VAIND = VAVGINIT - QINF
            DO I = 1, NRC
                BGAM(I, NR) = 0.0
            END DO
            BLDS = FLOAT(NRBLD(NR))
            !---- Under-relaxation to reduce transients in CL
            RLX = 0.5
            !
            DO 100 ITERG = 1, NITERG
                !
                TSUM = 0.0
                DO I = 1, NRC
                    XI = YRC(I, NR) / RTIP(NR)
                    DR = YRP(I + 1, NR) - YRP(I, NR)
                    !
                    !---- Use upstream circulation to calculate inflow
                    IF(IG.LE.1) THEN
                        VTIN = 0.0
                    ELSE
                        VTIN = BGAMG(IG - 1, I) * PI2I / YRC(I, NR)
                    ENDIF
                    SI = QINF + VAIND
                    CI = VTIN - YRC(I, NR) * OMEGA(NR)
                    !
                    WSQ = CI * CI + SI * SI
                    W = SQRT(WSQ)
                    PHI = ATAN2(SI, -CI)
                    !
                    ALF = BETAR(I, NR) - PHI
                    REY = CHR(I, NR) * ABS(W) * RHO / RMU
                    SECSIG = BLDS * CHR(I, NR) / (2.0 * PI * YRC(I, NR))
                    SECSTAGR = 0.5 * PI - BETAR(I, NR)
                    CALL GETCLCDCM(NR, I, XI, ALF, W, REY, SECSIG, SECSTAGR, &
                            CLB, CL_ALF, CL_W, &
                            CLMAX, CLMIN, DCL_STALL, LSTALLR(I, NR), &
                            CDRAG, CD_ALF, CD_W, CD_REY, &
                            CMOM, CM_AL, CM_W)
                    CLR(I, NR) = CLB
                    !c        CLALF(I,NR) = CL_ALF
                    !
                    BGAMNEW = 0.5 * CLR(I, NR) * W * CHR(I, NR) * BLDS
                    !
                    BGAMOLD = BGAM(I, NR)
                    DELBGAM = BGAMNEW - BGAMOLD
                    BGAM(I, NR) = BGAMOLD + RLX * DELBGAM
                    !
                    TSUM = TSUM - BGAM(I, NR) * RHO * CI * DR
                    !
                    !c        write(8,997) 'nr,i,alf,cl,gam,tsum ',nr,i,alf,clr(i,NR),
                    !c     &                                     bgam(i,NR),tsum
                    !
                    CALL UVINFL(YRC(I, NR), WWA, WWT)
                    !---- Set rotor slipstream velocities from estimates
                    VIND(1, I, NR) = VAIND
                    VIND(2, I, NR) = 0.0
                    VIND(3, I, NR) = CI + YRC(I, NR) * OMEGA(NR)&
                            + BGAM(I, NR) * PI2I / YRC(I, NR)
                ENDDO
                IF(TGAP.GT.0.0) THEN
                    BGAM(NRC, NR) = 0.0
                ENDIF
                !
                !---- use momentum theory estimate of duct induced axial velocity to set VA
                VHSQ = TSUM / (RHO * ADISK(NR))
                DVAIND = 0.0
                IF(NR.EQ.1) THEN
                    VAIND = -0.5 * QINF + SQRT((0.5 * QINF)**2 + VHSQ)
                ELSE
                    DVAIND = -0.5 * SI + SQRT((0.5 * SI)**2 + VHSQ)
                ENDIF
                !
                !---- Refine the initial guess with iteration using momentum theory
                !     to drive the axial velocity
                !       WRITE(*,*) 'ROTINITBLD noVind TSUM,VA ',TSUM,VAIND,DVAIND
                !       WRITE(8,*) 'ROTINITBLD noVind TSUM,VA ',TSUM,VAIND,DVAIND
                !
            100  CONTINUE
            !
            !---- Set average velocity in duct
            VAVGINIT = VAIND + QINF
            !---- Put circulation from disk into grid flow
            CALL ROTBG2GRD(NR)
            !
        ENDIF
        !
    END DO
    !
    CALL SETROTVEL
    LVMAV = .FALSE.
    !c      CALL VMAVGINIT(VAVGINIT)
    !
    997  format(A, ' ', i4, i4, 5(1x, f10.5))
    99   format(i5, 5(1x, f12.6))
    !      WRITE(*,*) 'ROTINITBLD No convergence'
    !
    RETURN
END


SUBROUTINE SETROTVEL
    !----------------------------------------------------------------
    !     Sets absolute and relative frame rotor velocities from
    !     induced velocities
    !     Assumes VIND abs. frame induced velocities (in common) are valid
    !----------------------------------------------------------------
    !     Blade blockage code, Esotec Developments, Sept 2013
    !----------------------------------------------------------------
    INCLUDE 'DFDC.inc'
    !
    DO NR = 1, NROTOR
        IF(LBLBL.AND..NOT.LBBLOFT(NR)) THEN
            WRITE(*, 1200) NR
            LBLBL = .FALSE.
        ENDIF
    ENDDO
    !
    1200 FORMAT(/, 'No blade blockage factors for Disk', I2)
    !
    DO NR = 1, NROTOR
        DO IR = 1, NRC
            !
            IF(LBLBL) THEN
                VFAC = BBVFAC(IR, NR)
            ELSE
                VFAC = 1.0
            ENDIF
            !
            CALL UVINFL(YRC(IR, NR), WWA, WWT)
            !---- Absolute frame velocities
            VABS(3, IR, NR) = VIND(3, IR, NR) + WWT
            VABS(1, IR, NR) = (VIND(1, IR, NR) + QINF + WWA) * VFAC  ! BB entry
            !        VABS(1,IR,NR) = VIND(1,IR,NR) + QINF + WWA      ! v0.70
            VABS(2, IR, NR) = VIND(2, IR, NR)
            VMA = SQRT(VABS(1, IR, NR)**2 + VABS(2, IR, NR)**2)
            VVA = SQRT(VMA**2 + VABS(3, IR, NR)**2)
            IF(VABS(3, IR, NR).NE.0.0) THEN
                PHIA = ATAN2(VMA, -VABS(3, IR, NR))
            ELSE
                PHIA = 0.5 * PI
            ENDIF
            !---- Relative frame velocities
            VREL(3, IR, NR) = VABS(3, IR, NR) - OMEGA(NR) * YRC(IR, NR)
            VREL(1, IR, NR) = VABS(1, IR, NR)
            VREL(2, IR, NR) = VABS(2, IR, NR)
            VMR = SQRT(VREL(1, IR, NR)**2 + VREL(2, IR, NR)**2)
            VVR = SQRT(VMR**2 + VREL(3, IR, NR)**2)
            IF(VREL(3, IR, NR).NE.0.0) THEN
                PHIR = ATAN2(VMR, -VREL(3, IR, NR))
            ELSE
                PHIR = 0.5 * PI
            ENDIF
            !
            IF(LDBG) THEN
                WRITE(*, 1400)
                WX = VREL(1, IR, NR)
                WR = VREL(2, IR, NR)
                WT = VREL(3, IR, NR)
                WM = SQRT(WX * WX + WR * WR)
                IF(WT.NE.0.0) THEN
                    PHIR = ATAN2(WM, -WT)
                ELSE
                    PHIR = 0.5 * PI
                ENDIF
                WRITE(*, 1401) YRC(IR, NR), WX, WR, WM, WT, PHIR / DTR, BGAM(IR, NR)
            ENDIF
        END DO
        !
    END DO
    !
    1400 FORMAT(/'Blade slipstream velocities set...'&
            /'     r          Wx         Wr         Wm', &
            '         Wt        Phi       BGam')
    1401 FORMAT(1X, 8G11.4)
    !
    RETURN
END


SUBROUTINE CONVGTH(NITER, RLXF, WXEPS)
    !----------------------------------------------------------------
    !     Basic solver for GTH,
    !     Uses underrelaxed iteration for fixed BGAM to converge GTH
    !----------------------------------------------------------------
    INCLUDE 'DFDC.inc'
    !
    DIMENSION GAMTH(IPX), DGOLD(IPX)
    !
    RLX = RLXF
    IF(RLX.LE.0.0) RLX = 0.5
    !
    !---- check for valid solution before iterating
    IF(.NOT.LGAMA) THEN
        IF(.NOT.LVMAV) CALL VMAVGINIT(VAVGINIT)
        !---- Generate GTH solution for current wakes
        CALL GTHCALC(GAMTH)
        !---- Update wake gamma from initial solution
        DO IP = 1, NPTOT
            GTH(IP) = GAMTH(IP)
        END DO
        !---- Generate GAM solution for current RHS
        CALL GAMSOLV
    ENDIF
    !
    DO IP = 1, NPTOT
        DGOLD(IP) = 0.0
    END DO
    !
    !----- do specified cycles of under-relaxed iteration
    DO ITR = 1, NITER
        !c         IF(LDBG) WRITE(*,110) ITR
        !
        !---- Set VMavg velocities at wake points
        CALL VMAVGCALC
        !---- Generate GTH solution for current wakes
        CALL GTHCALC(GAMTH)
        !---- Update wake gamma using CSOR
        IPMAX = 0
        DGTHMAX = 0.0
        RLX = RLXF
        DO IP = 1, NPTOT
            DG = GAMTH(IP) - GTH(IP)
            IF(ABS(DG).GT.ABS(DGTHMAX)) THEN
                DGTHMAX = DG
                IPMAX = IP
            ENDIF
            RLXG = RLX
            IF(DG * DGOLD(IP).LT.0.0) RLXG = 0.6 * RLX
            IF(DG * DGOLD(IP).GT.0.0) RLXG = 1.2 * RLX
            DGOLD(IP) = DG * RLXG
            GTH(IP) = GTH(IP) + RLXG * DG
        END DO
        !---- Generate GAM solution for current RHS
        LGAMA = .FALSE.
        CALL GAMSOLV
        !
        !c         IF(LDBG)
        WRITE(*, 100) ITR, DGTHMAX, IPMAX, RLX
        IF(ABS(DGTHMAX).LT.WXEPS * QREF) THEN
            LCONV = .TRUE.
            GO TO 20
        ENDIF
    END DO
    LCONV = .FALSE.
    !
    100  FORMAT(I3, ' dGTHmax=', F9.5, ' @IP=', I5, ' RLX=', F8.5)
    120  FORMAT(1X, 7G11.4)
    !
    !---- Update rotor velocities
    20   CALL UPDROTVEL
    !
    RETURN
END


SUBROUTINE CONVGTHT(NITER, RLXF, WXEPS, TSPEC, ISPEC)
    !----------------------------------------------------------------
    !     Basic solver for B*GAM,GTH for design mode (fixed thrust)
    !     Uses underrelaxed iteration for fixed BGAM to converge GTH
    !     Input:  TSPEC   thrust specification
    !             ISPEC   1 for rotor thrust spec, 2 for total thrust spec
    !----------------------------------------------------------------
    INCLUDE 'DFDC.inc'
    !
    DIMENSION GAMTH(IPX), DGOLD(IPX)
    DIMENSION BGX(IRX)
    !
    RLX = RLXF
    IF(RLX.LE.0.0) RLX = 0.5
    !
    !---- check for valid solution before iterating
    IF(.NOT.LGAMA) THEN
        IF(.NOT.LVMAV) CALL VMAVGINIT(VAVGINIT)
        !---- Generate GTH solution for current wakes
        CALL GTHCALC(GAMTH)
        !---- Update wake gamma from initial solution
        DO IP = 1, NPTOT
            GTH(IP) = GAMTH(IP)
        END DO
        !---- Generate GAM solution for current RHS
        CALL GAMSOLV
    ENDIF
    !
    DO IP = 1, NPTOT
        DGOLD(IP) = 0.0
    END DO
    !
    !----- Iteration loop for driving thrust using B*GAM
    NR = 1
    BLDS = FLOAT(NRBLD(NR))
    DO ITR = 1, NITER
        !c         IF(LDBG) WRITE(*,110) ITR
        !---- Update rotor velocities
        CALL UPDROTVEL
        !
        BGAV = 0.0
        BGMAX = BGAM(1, NR)
        BGMIN = BGMAX
        DO IR = 1, NRC
            DR = YRP(IR + 1, NR) - YRP(IR, NR)
            DA = PI * (YRP(IR + 1, NR)**2 - YRP(IR, NR)**2)
            BGAV = BGAV + BGAM(IR, NR)
            BGMAX = MAX(BGMAX, BGAM(IR, NR))
            BGMIN = MIN(BGMIN, BGAM(IR, NR))
        END DO
        BGAV = BGAV / FLOAT(NRC)
        BGMAG = MAX(ABS(BGAV), BGMIN, BGMAX, 0.1)
        !
        !---- Calculate current rotor thrust
        CALL TQCALC(1)
        !---- Drive thrust from rotor for ISPEC=1, total thrust for ISPEC=2
        IF(ISPEC.EQ.1) THEN
            THR = TTOT
        ELSE
            THR = TTOT + TDUCT
        ENDIF
        !---- Scale factor for BGAM from current value to get desired rotor thrust
        TSCL = 1.0
        IF(THR.NE.0.0)  TSCL = TSPEC / THR
        !
        !---- Check for rational relaxation factors based on BGAM changes
        DBGMAX = 0.0
        RLXB = RLX
        DO IR = 1, NRC
            DBG = (TSCL - 1.0) * BGAM(IR, NR)
            DBGMAX = MAX(DBGMAX, ABS(DBG))
            IF(BGMAG.NE.0.0) THEN
                FDBG = ABS(DBG) / BGMAG
                IF(FDBG * RLXB.GT.0.3) RLXB = 0.3 / FDBG
            ENDIF
        END DO
        !
        DO IR = 1, NRC
            DBG = (TSCL - 1.0) * BGAM(IR, NR)
            !---- Update BGAM
            BGAM(IR, NR) = BGAM(IR, NR) + RLXB * DBG
        END DO
        IF(TGAP.GT.0.0) BGAM(NRC, NR) = 0.0
        !
        !---- Set VMavg velocities at wake points
        CALL VMAVGCALC
        !---- Generate GTH estimate for updated circulations
        CALL GTHCALC(GAMTH)
        IPMAX = 0
        DGTHMAX = 0.0
        DO IP = 1, NPTOT
            DG = GAMTH(IP) - GTH(IP)
            IF(ABS(DG).GT.ABS(DGTHMAX)) THEN
                DGTHMAX = DG
                IPMAX = IP
            ENDIF
            RLXG = RLXB
            IF(DG * DGOLD(IP).LT.0.0) RLXG = 0.6 * RLXB
            IF(DG * DGOLD(IP).GT.0.0) RLXG = 1.2 * RLXB
            DGOLD(IP) = DG * RLXG
            !---- Update GTH wake gamma using CSOR
            GTH(IP) = GTH(IP) + RLXG * DG
        END DO
        !
        !---- Generate GAM solution for current RHS
        LGAMA = .FALSE.
        CALL GAMSOLV
        !
        !c       IF(LDBG) THEN
        !c         WRITE(*,*) ' '
        WRITE(*, 100) ITR, DGTHMAX, IPMAX, DBGMAX, RLXB
        IF(ABS(DGTHMAX).LT.WXEPS * QREF .AND.&
                ABS(DBGMAX).LE.0.001 * BGMAG) THEN
            LCONV = .TRUE.
            GO TO 20
        ENDIF
        LGAMA = .FALSE.
    END DO
    LCONV = .FALSE.
    !
    100  FORMAT(I3, ' dGTHmax=', F9.5, ' @IP=', I5, &
            '  dBGmax=', F9.5, ' RLX=', F8.5)
    110  FORMAT(/'Blade velocities on iteration ', I5, &
            /'     r          Wx         Wr', &
            '         Wt        Phi       CL       BGam')
    120  FORMAT(1X, 7G11.4)
    !
    !---- Update rotor velocities
    20   CALL UPDROTVEL
    !
    RETURN
END


SUBROUTINE CONVGTHBG(NITER, RLXF, WXEPS)
    !----------------------------------------------------------------
    !     Basic solver for GTH for a defined blade geometry
    !     Uses underrelaxed iteration to converge GTH, BGAM
    !----------------------------------------------------------------
    INCLUDE 'DFDC.inc'
    !
    DIMENSION GAMTH(IPX), DGOLD(IPX)
    DIMENSION BGX(IRX), DBGOLD(IRX)
    !
    RLX = RLXF
    IF(RLX.LE.0.0) RLX = 0.5
    !
    !---- check for valid solution before iterating
    IF(.NOT.LGAMA) THEN
        IF(.NOT.LVMAV) CALL VMAVGINIT(VAVGINIT)
        !---- Generate GTH solution for current wakes
        CALL GTHCALC(GAMTH)
        !---- Update wake gamma from initial solution
        DO IP = 1, NPTOT
            GTH(IP) = GAMTH(IP)
        END DO
        !---- Generate GAM solution for current RHS
        CALL GAMSOLV
    ENDIF
    !
    DO IP = 1, NPTOT
        DGOLD(IP) = 0.0
    END DO
    DO IR = 1, NRC
        DBGOLD(IR) = 0.0
    END DO
    !
    !c      write(15,*) 'new solution '
    !----- do several cycles of under-relaxed iteration to converge
    !      BGAM and GTH from specified CL and chord
    DO ITR = 1, NITER
        !c           write(15,*) 'iter ',itr
        !c         IF(LDBG) WRITE(*,110) ITR
        !
        !---- Generate GAM solution for current RHS
        CALL GAMSOLV
        !---- Update rotor velocities
        CALL UPDROTVEL
        !
        RLXG = 0.0
        RLXBG = 0.0
        DBGMAX = 0.0
        DGTHMAX = 0.0
        !
        DO NR = 1, NROTOR
            IF(IRTYPE(NR).EQ.2) THEN
                IG = IGROTOR(NR)
                !
                BLDS = FLOAT(NRBLD(NR))
                !---- convert to blade relative velocities
                BGAV = 0.0
                BGMAX = BGAM(1, NR)
                BGMIN = BGMAX
                DO IR = 1, NRC
                    !---- theta velocity at blade lifting line
                    VTBG = BGAM(IR, NR) * PI2I / YRC(IR, NR)
                    WTB = VREL(3, IR, NR) - 0.5 * VTBG
                    !
                    !           IF(NR.EQ.1) THEN
                    !             CIRC = 0.0
                    !           ELSE
                    !             CIRC = BGAMG(IG-1,IR)
                    !           ENDIF
                    !           VTBG = BGAM(IR,NR)*PI2I/YRC(IR,NR)
                    !           VTIN = CIRC*PI2I/YRC(IR,NR)
                    !           VROT = - OMEGA(NR)*YRC(IR,NR)
                    !           WTB = VTIN - OMEGA(NR)*YRC(IR,NR) + 0.5*VTBG
                    !
                    WWB = SQRT(VREL(1, IR, NR)**2 + WTB**2)
                    PHIB = ATAN2(VREL(1, IR, NR), -WTB)
                    !
                    !           write(15,89) 'n,i,vin,vbg,vout,wtb,phi ',nr,ir,VTIN,
                    !     &                     VTBG,VREL(3,IR,NR),WTB,phib/dtr,vrot
                    ! 89        format(a,2i4,6F12.5)
                    !
                    XI = YRC(IR, NR) / RTIP(NR)
                    ALF = BETAR(IR, NR) - PHIB
                    REY = WWB * CHR(IR, NR) * RHO / RMU
                    SECSIG = BLDS * CHR(IR, NR) / (2.0 * PI * YRC(IR, NR))
                    SECSTAGR = 0.5 * PI - BETAR(IR, NR)
                    CALL GETCLCDCM(NR, IR, XI, ALF, WWB, REY, SECSIG, SECSTAGR, &
                            CLB, CL_ALF, CL_W, &
                            CLMAX, CLMIN, DCL_STALL, LSTALLR(IR, NR), &
                            CDR(IR, NR), CD_ALF, CD_W, CD_REY, &
                            CMOM, CM_AL, CM_W)
                    CLR(IR, NR) = CLB
                    CLALF(IR, NR) = CL_ALF
                    ALFAR(IR, NR) = ALF
                    !
                    BGX(IR) = BLDS * 0.5 * WWB * CHR(IR, NR) * CLR(IR, NR)
                    BGAV = BGAV + BGAM(IR, NR)
                    BGMAX = MAX(BGMAX, BGAM(IR, NR))
                    BGMIN = MIN(BGMIN, BGAM(IR, NR))
                    !
                    IF(LDBG) THEN
                        !            WRITE(*,120) YRC(IR,NR),
                        !     &                   VREL(1,IR,NR),VREL(2,IR,NR),WTB,
                        !     &                   PHIB/DTR,CLR(IR,NR),BGX(IR),CLALF(IR,NR)
                        WRITE(*, 120) YRC(IR, NR), &
                                VREL(1, IR, NR), VREL(2, IR, NR), WTB, &
                                PHIB / DTR, CLR(IR, NR), BGX(IR), CLALF(IR, NR)
                    ENDIF
                END DO
                BGAV = BGAV / FLOAT(NRC)
                IF(BGAV.GE.0.0) THEN
                    BGMAG = MAX(BGAV, BGMAX, 0.1)
                ELSE
                    BGMAG = MIN(BGAV, BGMIN, -0.1)
                ENDIF
                IF(TGAP.GT.0.0 .AND. OMEGA(NR).NE.0.0) THEN
                    BGX(NRC) = 0.0
                    CLR(NRC, NR) = 0.0
                    ALFAR(NRC, NR) = 0.0
                ENDIF
                !
                !---- Check for rational relaxation factors based on BGAM changes
                RLXB = RLX
                IRMAX = 0
                DBGMAX = 0.0
                DO IR = 1, NRC
                    DBG = (BGX(IR) - BGAM(IR, NR))
                    IF(ABS(DBG).GT.ABS(DBGMAX)) THEN
                        DBGMAX = DBG
                        IRMAX = IR
                    ENDIF
                    IF(BGMAG.NE.0.0) THEN
                        !             FDBG = ABS(DBG)/BGAM(IR,NR)
                        !             IF(FDBG*RLXB.GT.0.5) RLXB = 0.5/FDBG
                        !             FDBG = DBG/BGAM(IR,NR)
                        FDBG = DBG / BGMAG
                        IF(FDBG * RLXB.LT.-0.2) RLXB = -0.2 / FDBG
                        IF(FDBG * RLXB.GT. 0.4) RLXB = 0.4 / FDBG
                    ENDIF
                END DO
                !
                !---- Update blade circulation using CSOR
                DO IR = 1, NRC
                    DBG = (BGX(IR) - BGAM(IR, NR))
                    RLXBG = 0.5 * RLXB
                    IF(DBG * DBGOLD(IR).LT.0.0) RLXBG = 0.6 * RLXB
                    !            IF(DBG*DBGOLD(IR).GT.0.0) RLXBG = 1.2*RLXB
                    DBGOLD(IR) = DBG * RLXBG
                    BGAM(IR, NR) = BGAM(IR, NR) + RLXBG * DBG
                END DO
                IF(TGAP.GT.0.0 .AND. OMEGA(NR).NE.0.0) BGAM(NRC, NR) = 0.0
                !---- Update grid flowfield
                CALL SETGRDFLW
            ENDIF
            !
        END DO ! loop over NROTOR
        !
        !---- Set VMavg velocities at wake points
        CALL VMAVGCALC
        !---- Generate GTH estimate for updated circulations
        CALL GTHCALC(GAMTH)
        IPMAX = 0
        DGTHMAX = 0.0
        DO IP = 1, NPTOT
            DG = GAMTH(IP) - GTH(IP)
            IF(ABS(DG).GT.ABS(DGTHMAX)) THEN
                DGTHMAX = DG
                IPMAX = IP
            ENDIF
            RLXG = RLX
            IF(DG * DGOLD(IP).LT.0.0) RLXG = 0.6 * RLX
            IF(DG * DGOLD(IP).GT.0.0) RLXG = 1.2 * RLX
            DGOLD(IP) = DG * RLXG
            !---- Update GTH wake gamma using CSOR
            GTH(IP) = GTH(IP) + RLXG * DG
        END DO
        !
        !---- Generate GAM solution for current RHS
        LGAMA = .FALSE.
        !cc         CALL GAMSOLV
        !
        !c       IF(LDBG) THEN
        !c         WRITE(*,*) ' '
        IF(RLXBG.NE.0.0) THEN
            WRITE(*, 100) ITR, DGTHMAX, IPMAX, DBGMAX, IRMAX, RLXBG
            !c           WRITE(*,100) ITR,DGTHMAX,IPMAX,DBGMAX,IRMAX,RLXBG,BGMAG
        ELSE
            WRITE(*, 105) ITR, DGTHMAX, IPMAX, RLXG
        ENDIF
        IF(ABS(DGTHMAX).LT.WXEPS * QREF .AND.&
                ABS(DBGMAX).LE.0.001 * ABS(BGMAG)) THEN
            LCONV = .TRUE.
            GO TO 20
        ENDIF
        LGAMA = .FALSE.
    END DO
    LCONV = .FALSE.
    !
    100  FORMAT(I3, ' dGTHmax=', F10.5, ' @IP=', I4, &
            '  dBGmax=', F10.5, ' @IR=', I4, ' RLX=', F8.5)
    !c     &          '  dBGmax=',F10.5,' @IR=',I4,' RLX=',F8.5,' BGMG=',F8.5)
    105  FORMAT(I3, ' dGTHmax=', F10.5, ' @IP=', I4, ' RLX=', F8.5)
    110  FORMAT(/'Disk velocities on iteration ', I4, &
            /'     r          Wx         Wr', &
            '         Wt        Phi       CL       BGam      CLalf')
    120  FORMAT(1X, 8G10.4)
    !
    !---- Update rotor velocities
    20   CALL UPDROTVEL
    !
    RETURN
END


SUBROUTINE CONVGTHBGT(NITER, RLXF, WXEPS, TSPEC, ISPEC)
    !----------------------------------------------------------------
    !     Basic solver for BETA, GTH for analysis mode (fixed thrust)
    !     Uses underrelaxed iteration for blade pitch to converge BGAM,GTH
    !     Input:  TSPEC   thrust specification
    !             ISPEC   1 for rotor thrust spec, 2 for total thrust spec
    !----------------------------------------------------------------
    INCLUDE 'DFDC.inc'
    !
    DIMENSION GAMTH(IPX)
    DIMENSION BGX(IRX)
    !
    RLX = RLXF
    IF(RLX.LE.0.0) RLX = 0.5
    !
    !---- check for valid solution before iterating
    IF(.NOT.LGAMA) THEN
        !---- Generate GAM solution for current RHS
        CALL GAMSOLV
    ENDIF
    !
    !----- do several cycles of under-relaxed iteration to converge
    !      BGAM and GTH from specified CL and chord
    NR = 1
    BLDS = FLOAT(NRBLD(NR))
    DO ITR = 1, NITER
        !c         IF(LDBG) WRITE(*,110) ITR
        !
        BGEPS = 20.0 * WXEPS
        RLXB = RLXF
        NITER0 = MIN(3, NITER / 2)
        CALL CONVGTHBG(NITER, RLXB, BGEPS)
        !
        CALL TQCALC(1)
        !---- Drive thrust from rotor for ISPEC=1, total thrust for ISPEC=2
        IF(ISPEC.EQ.1) THEN
            THR = TTOT
        ELSE
            THR = TTOT + TDUCT
        ENDIF
        !
        !---- Check for disk type (actuator disk or bladed)
        IF(IRTYPE(NR).EQ.1) THEN
            !---- Actuator disk
            BGAV = 0.0
            BGMAX = BGAM(1, NR)
            BGMIN = BGMAX
            DO IR = 1, NRC
                DR = YRP(IR + 1, NR) - YRP(IR, NR)
                DA = PI * (YRP(IR + 1, NR)**2 - YRP(IR, NR)**2)
                BGAV = BGAV + BGAM(IR, NR)
                BGMAX = MAX(BGMAX, BGAM(IR, NR))
                BGMIN = MIN(BGMIN, BGAM(IR, NR))
            END DO
            BGAV = BGAV / FLOAT(NRC)
            BGMAG = MAX(ABS(BGAV), BGMIN, BGMAX, 0.1)
            !---- Scale factor for BGAM from current value to get desired rotor thrust
            TSCL = 1.0
            IF(THR.NE.0.0)  TSCL = TSPEC / THR
            !---- Check for rational relaxation factors based on BGAM changes
            DBGMAX = 0.0
            RLXB = RLX
            DO IR = 1, NRC
                DBG = (TSCL - 1.0) * BGAM(IR, NR)
                DBGMAX = MAX(DBGMAX, ABS(DBG))
                IF(BGMAG.NE.0.0) THEN
                    FDBG = ABS(DBG) / BGMAG
                    IF(FDBG * RLXB.GT.0.3) RLXB = 0.3 / FDBG
                ENDIF
            END DO
            !---- Update BGAM
            DO IR = 1, NRC
                BGFAC = (TSCL - 1.0) * BGAM(IR, NR)
                BGAM(IR, NR) = BGAM(IR, NR) + RLXB * BGFAC
            END DO
            IF(TGAP.GT.0.0 .AND. OMEGA(NR).NE.0.0) BGAM(NRC, NR) = 0.0
            !
            WRITE(*, 110) ITR, RLXB, DBGMAX * RLXB
            IF(ABS(DBGMAX * RLXB).LE.0.001 * BGMAG) THEN
                LCONV = .TRUE.
                GO TO 20
            ENDIF
            LGAMA = .FALSE.
            !
        ELSEIF(IRTYPE(NR).EQ.2) THEN
            !---- Bladed disk
            DTDALF = 0.0
            DO IR = 1, NRC
                !---- theta velocity at blade (use only 1/2 of induced Vt from circulation)
                VTBG = BGAM(IR, NR) * PI2I / YRC(IR, NR)
                WTB = VREL(3, IR, NR) - 0.5 * VTBG
                WWB = SQRT(VREL(1, IR, NR)**2 + WTB**2)
                PHIB = ATAN2(VREL(1, IR, NR), -WTB)
                !
                XI = YRC(IR, NR) / RTIP(NR)
                ALF = BETAR(IR, NR) - PHIB
                REY = WWB * CHR(IR, NR) * RHO / RMU
                SECSIG = BLDS * CHR(IR, NR) / (2.0 * PI * YRC(IR, NR))
                SECSTAGR = 0.5 * PI - BETAR(IR, NR)
                CALL GETCLCDCM(NR, IR, XI, ALF, WWB, REY, SECSIG, SECSTAGR, &
                        CLB, CL_ALF, CL_W, &
                        CLMAX, CLMIN, DCL_STALL, LSTALLR(IR, NR), &
                        CDR(IR, NR), CD_ALF, CD_W, CD_REY, &
                        CMOM, CM_AL, CM_W)
                CLR(IR, NR) = CLB
                CLALF(IR, NR) = CL_ALF
                ALFAR(IR, NR) = ALF
                !
                IF(IR.EQ.NRC .AND. TGAP.GT.0.0 .AND. OMEGA(NR).NE.0.0) THEN
                    CLR(IR, NR) = 0.0
                    CLALF(IR, NR) = 0.0
                    ALFAR(IR, NR) = 0.0
                ENDIF
                !
                DTDALF = DTDALF + TI_GAM(IR, NR) * 0.5 * WWB * CHR(IR, NR) * CL_ALF
            END DO
            !---- Change blade pitch to drive thrust
            RLXB = RLXF
            DBETA = 0.0
            IF(DTDALF.NE.0.0) DBETA = (TSPEC - THR) / DTDALF
            !---- Limit DBETA changes in iteration to get desired rotor thrust
            IF(ABS(DBETA) * RLXB.GT.0.1) RLXB = 0.1 / ABS(DBETA)
            !---- update BETA by estimate
            DO IR = 1, NRC
                BETAR(IR, NR) = BETAR(IR, NR) + RLXB * DBETA
            END DO
            !
            WRITE(*, 100) ITR, RLXB, DBETA / DTR
            IF(ABS(DBETA).LT.0.001) THEN
                LCONV = .TRUE.
                GO TO 20
            ENDIF
            LGAMA = .FALSE.
            !
        ENDIF
        !
    END DO
    LCONV = .FALSE.
    !
    100  FORMAT(I3, ' RLX=', F8.5, ' dBeta=', F9.5)
    110  FORMAT(I3, ' RLX=', F8.5, ' dBGmax=', F9.5)
    !
    !---- Final iterations to converge case
    20   CALL CONVGTHBG(NITER, RLXF, WXEPS)
    !---- Update rotor velocities
    CALL UPDROTVEL
    !
    RETURN
END


SUBROUTINE UPDROTVEL
    !----------------------------------------------------------------
    !     Update blade or disk velocities based on current solution
    !     Velocities updated include:
    !         induced        velocities  VIND
    !         absolute frame velocities  VABS
    !         relative frame velocities  VREL
    !----------------------------------------------------------------
    INCLUDE 'DFDC.inc'
    !
    !---- get induced velocities upstream and downstream of disk
    DO N = 1, NROTOR
        CALL ROTORVABS(N, VIND(1, 1, N))
    END DO
    !
    !---- set disk downstream velocities in absolute and relative frames
    CALL SETROTVEL
    !
    !---- get area-averaged axial velocity over disk
    DO N = 1, NROTOR
        AINT = 0.0
        VAINT = 0.0
        DO IR = 1, NRC
            DR = YRP(IR + 1, N) - YRP(IR, N)
            DA = PI * (YRP(IR + 1, N)**2 - YRP(IR, N)**2)
            US = VABS(1, IR, N)
            AINT = AINT + DA
            VAINT = VAINT + US * DA
        END DO
        VAAVG(N) = VAINT / AINT
        !c       write(*,*) 'n,vaavg ',n,vaavg(n)
    END DO
    !
    RETURN
END


SUBROUTINE VABS2VREL(OMEG, YA, &
        VXA, VRA, VTA, &
        VXR, VRR, VTR, VTR_VTA, VTR_OMG)
    !--------------------------------------------------------------
    !     Calculates relative frame induced velocities from
    !     absolute frame velocities at radius YA with rotational
    !     speed OMEG.
    !--------------------------------------------------------------
    !
    VXR = VXA
    VRR = VRA
    !---- Blade relative velocity includes rotational speed and swirl effects
    VTR = VTA - OMEG * YA
    VTR_VTA = 1.0
    VTR_OMG = -YA
    !
    RETURN
END


SUBROUTINE ROTORVABS(N, VEL)
    !--------------------------------------------------------------
    !     Get absolute frame induced velocities downstream of rotor
    !     line center points
    !--------------------------------------------------------------
    INCLUDE 'DFDC.inc'
    DIMENSION VEL(3, *)
    !
    !---- get velocities on rotor source line
    IEL = IELROTOR(N)
    IC1 = ICFRST(IEL)
    IC2 = ICLAST(IEL)
    IG = IGROTOR(N)
    !
    DO IC = IC1, IC2
        IR = IC - IC1 + 1
        !---- Use mean surface velocity on rotor source panel
        VEL(1, IR) = QC(1, IC) - QINF
        VEL(2, IR) = QC(2, IC)
        !---- Circumferential velocity downstream of rotor due to circulation
        !        IF(IG.EQ.1) THEN
        BGAVE = BGAMG(IG, IR)
        !        ELSE
        !        BGAVE = 0.5*(BGAMG(IG-1,IR)+BGAMG(IG,IR))
        !        ENDIF
        CIRC = BGAVE
        VEL(3, IR) = CIRC * PI2I / YC(IC)
    END DO
    !
    98   FORMAT(A, I5, 6(1X, F10.6))
    99   FORMAT(A, 2I5, 6(1X, F10.6))
    97   FORMAT(A, 3I5, 6(1X, F10.6))
    !
    RETURN
END


SUBROUTINE GETVELABS(NF, XF, YF, VEL)
    !--------------------------------------------------------------
    !     Get absolute frame induced velocities at NF points XF,YF
    !     by potential flow survey
    !--------------------------------------------------------------
    INCLUDE 'DFDC.inc'
    DIMENSION XF(*), YF(*)
    DIMENSION VEL(3, *)
    !
    !---- local arrays for calling QFCALC
    PARAMETER (NFX = IRX)
    DIMENSION QF(2, NFX), &
            QF_GAM(2, IPX, NFX), &
            QF_SIG(2, IPX, NFX), &
            QF_GTH(2, IPX, NFX)
    DIMENSION IPFO(NFX), IPFP(NFX), IFTYPE(NFX)
    !
    !---- get velocities on specified points
    !---- assume the pointa are not on a panel
    !
    DO IR = 1, NF
        IPFO(IR) = 0
        IPFP(IR) = 0
        IFTYPE(IR) = 0
    END DO
    !
    !------ evaluate velocity components at points
    CALL QFCALC(1, NF, XF, YF, IPFO, IPFP, IFTYPE, &
            QF, QF_GAM, QF_SIG, QF_GTH)
    !
    DO IF = 1, NF
        VEL(1, IF) = QF(1, IF)
        VEL(2, IF) = QF(2, IF)
        VEL(3, IF) = 0.0
    END DO
    !
    RETURN
END


SUBROUTINE PRTVEL(LU, LINE, LIND, LABS, LREL, NR)
    !----------------------------------------------------------
    !     Print out velocities just downstream of rotor
    !     Prints either:
    !        absolute frame induced velocities
    !        absolute frame total velocities
    !        blade relative frame total velocities
    !
    !     LU is logical unit for output
    !     LINE is a title message for table
    !     Print flags LIND,LREL,LABS control what gets printed
    !     NR is disk # for rotor
    !
    !     Takes VIND from current solution for absolute frame
    !     Takes VABS from current solution for absolute frame
    !     Takes VREL from current solution for relative frame
    !----------------------------------------------------------
    INCLUDE 'DFDC.inc'
    CHARACTER*(*) LINE
    LOGICAL LIND, LABS, LREL
    !
    !---- Print velocity data
    WRITE(LU, 20) LINE
    !
    RPM = 30.0 * OMEGA(NR) / PI
    WRITE(LU, 25) QINF, QREF, OMEGA(NR), RPM
    !
    !---- Absolute frame induced velocities
    IF(LIND) THEN
        WRITE(LU, 30)
        DO I = 1, NRC
            YY = YRC(I, NR)
            VXA = VIND(1, I, NR)
            VRA = VIND(2, I, NR)
            VMA = SQRT(VXA**2 + VRA**2)
            VTA = VIND(3, I, NR)
            VVA = SQRT(VMA**2 + VTA**2)
            !c          ANG = ATAN2(VTA,VMA)
            ANG = ATAN2(VTA, VXA)
            WRITE(LU, 50) YY, VXA, VRA, VMA, VTA, VVA, ANG / DTR
        END DO
    ENDIF
    !
    !---- Absolute frame velocities
    IF(LABS) THEN
        WRITE(LU, 35)
        DO I = 1, NRC
            YY = YRC(I, NR)
            VXA = VABS(1, I, NR)
            VRA = VABS(2, I, NR)
            VMA = SQRT(VXA**2 + VRA**2)
            VTA = VABS(3, I, NR)
            VVA = SQRT(VMA**2 + VTA**2)
            !c          ANG = ATAN2(VTA,VMA)
            ANG = ATAN2(VTA, VXA)
            WRITE(LU, 50) YY, VXA, VRA, VMA, VTA, VVA, ANG / DTR
        END DO
    ENDIF
    !
    !---- Relative frame velocities
    IF(LREL) THEN
        WRITE(LU, 40)
        DO I = 1, NRC
            YY = YRC(I, NR)
            WXR = VREL(1, I, NR)
            WRR = VREL(2, I, NR)
            WMR = SQRT(WXR**2 + WRR**2)
            !---- Blade relative velocity includes rotational speed
            WTR = VREL(3, I, NR)
            WWR = SQRT(WMR**2 + WTR**2)
            IF(WTR.NE.0.0) THEN
                !c            PHIR = ATAN2(WMR,-WTR)
                PHIR = ATAN2(WXR, -WTR)
            ELSE
                PHIR = 0.5 * PI
            ENDIF
            ANG = PHIR
            WRITE(LU, 50) YY, WXR, WRR, WMR, WTR, WWR, ANG / DTR
        END DO
    ENDIF
    !
    !---- Relative frame velocities on blade lifting line
    !     this assumes that the radial component of velocity is parallel
    !     to the blade span and is ignored in velocity magnitude and angle
    !     for the blade.  Radial components are printed however.
    IF(LREL) THEN
        WRITE(LU, 60)
        DO I = 1, NRC
            YY = YRC(I, NR)
            WXR = VREL(1, I, NR)
            WRR = VREL(2, I, NR)
            WMR = SQRT(WXR**2 + WRR**2)
            !---- Blade relative velocity includes rotational speed, 1/2 induced swirl
            !---- Angle measured from plane of rotation
            VTBG = BGAM(I, NR) * PI2I / YRC(I, NR)
            WTR = VREL(3, I, NR) - 0.5 * VTBG
            WWR = SQRT(WMR**2 + WTR**2)
            IF(WTR.NE.0.0) THEN
                PHIB = ATAN2(WXR, -WTR)
            ELSE
                PHIB = 0.5 * PI
            ENDIF
            ANG = PHIB
            WRITE(LU, 50) YY, WXR, WRR, WMR, WTR, WWR, ANG / DTR
        END DO
    ENDIF
    !
    20   FORMAT(/, A)
    25   FORMAT(' QINF  =', F12.4, &
            /' QREF  =', F12.4, &
            /' OMEGA =', F12.4, &
            /' RPM   =', F12.4)
    30   FORMAT(/'Induced vel, flow angles in absolute frame', &
            ' (downstream of disk)', &
            /'     r          Vxi        Vri', &
            '        Vmi        Vti        Vi     Swirl(deg)')
    35   FORMAT(/'Velocities, flow angles in absolute frame', &
            ' (downstream of disk)', &
            /'     r          Vx         Vr', &
            '         Vm         Vt         V     Swirl(deg)')
    40   FORMAT(/'Velocities, flow angles relative to blade frame', &
            ' (downstream of disk)', &
            /'     r          Wx         Wr', &
            '         Wm         Wt         W       Phi(deg)')
    60   FORMAT(/'Velocities in blade frame,', &
            ' on blade lifting line', &
            /'flow angle from plane of rotation', &
            /'     r          Wx         Wr', &
            '         Wm         Wt         W       Phi(deg)')
    !                  12345678901123456789011234567890112345678901
    50   FORMAT(7G11.4)
    !
    RETURN
END


SUBROUTINE SHOWDUCT(LU)
    !-------------------------------------------------------
    !     Displays duct geometric data
    !-------------------------------------------------------
    INCLUDE 'DFDC.inc'
    !
    NR = 1
    WRITE(LU, 100) NAME
    WRITE(LU, 125) QINF, QREF, VSO, RHO, RMU
    WRITE(LU, 150) ANAME, NBEL
    !
    DO N = 1, NBEL
        WRITE(LU, 300) XBLE(N), YBLE(N), &
                XBTE(N), YBTE(N), &
                XBREFE(N), YBREFE(N), &
                VOLUMV(N), ASURFV(N), &
                XBCENV(N), YBCENV(N), &
                RGYRXV(N), RGYRYV(N)
    END DO
    !
    !     &  AREA2DA(NEX),XBCEN2DA(NEX),YBCEN2DA(NEX),
    !     &  EIXX2DA(NEX),EIYY2DA(NEX), EIXY2DA(NEX),
    !     &  AREA2DT(NEX),XBCEN2DT(NEX),YBCEN2DT(NEX),
    !     &  EIXX2DT(NEX),EIYY2DT(NEX), EIXY2DT(NEX),
    !
    !     &  VOLUMV(NEX), ASURFV(NEX),  XBCENV(NEX), YBCENV(NEX),
    !     &  RGYRXV(NEX), RGYRYV(NEX),
    !     &  VOLUMVT(NEX),ASURFVT(NEX),XBCENVT(NEX),YBCENVT(NEX),
    !     &  RGYRXVT(NEX), RGYRYVT(NEX),
    !
    100 FORMAT(/, ' DFDC Case: ', A30, /, 1X, 55('-'))
    125 FORMAT('  Qinf  ', F9.4, '     Qref  ', F9.4, &
            /, '  Speed of sound (m/s)     ', F10.3, &
            /, '  Air density   (kg/m^3)   ', F10.5, &
            /, '  Air viscosity (kg/m-s)    ', E11.4)
    !
    150 FORMAT(/, ' Geometry name: ', A30, &
            /, ' Current duct geometry with', I2, ' elements:')
    !
    300 FORMAT(/, '  Xle   ', F12.5, '     Rle   ', F12.5, &
            /, '  Xte   ', F12.5, '     Rte   ', F12.5, &
            /, '  Xref  ', F12.5, '     Rref  ', F12.5, &
            /, '  Vol   ', F12.6, '     Asurf ', F12.6, &
            /, '  Xcent ', F12.6, '     Rcent ', F12.6, &
            /, '  rGYRx ', F12.6, '     rGYRr ', F12.6)
    !
    RETURN
END
! SHOWDUCT


SUBROUTINE SHOWACTDSK(LU)
    !-------------------------------------------------------
    !     Displays parameters on actuator disk
    !-------------------------------------------------------
    INCLUDE 'DFDC.inc'
    !
    DO N = 1, NROTOR
        !
        IF(IRTYPE(N).EQ.1) THEN
            !        WRITE(LU,100) NAME
            RPM = 30.0 * OMEGA(N) / PI
            !
            WRITE(LU, 120) N, OMEGA(N), RPM, RHUB(N), RTIP(N), ADISK(N)
            WRITE(LU, 200)
            !
            DO IR = 1, NRC
                WRITE(LU, 210) YRC(IR, N), YRC(IR, N) / RTIP(N), BGAM(IR, N)
            END DO
        ENDIF
        !
    END DO
    !
    100 FORMAT(/A)
    !
    120 FORMAT(/' Current Actuator Disk at Disk', I3, &
            / '  Omega  ', F12.4, '    Rpm    ', F11.2, &
            / '  Rhub   ', F12.5, '    Rtip   ', F11.5, &
            / '  Aswept ', F12.5)

    200 FORMAT('     r        r/R       B*Gamma')
    210 FORMAT(1X, 7G11.4)
    !
    RETURN
END
! SHOWACTDSK


SUBROUTINE SHOWBLADE(LU)
    !-------------------------------------------------------
    !     Displays chord, blade angle and solidity distribution
    !     on rotor blade
    !-------------------------------------------------------
    INCLUDE 'DFDC.inc'
    !
    DO N = 1, NROTOR
        !
        IF(IRTYPE(N).EQ.2) THEN
            RPM = 30.0 * OMEGA(N) / PI
            !
            WRITE(LU, 120) N, OMEGA(N), RPM, RHUB(N), &
                    RTIP(N), NRBLD(N), ADISK(N)
            BLDS = FLOAT(NRBLD(N))
            WRITE(LU, 200)
            !
            DO IR = 1, NRC
                SIGROT = BLDS * CHR(IR, N) / (2.0 * PI * YRC(IR, N))
                WRITE(LU, 210) YRC(IR, N), YRC(IR, N) / RTIP(N), &
                        CHR(IR, N), BETAR(IR, N) / DTR, SIGROT
            END DO
        ENDIF
        !
    END DO
    !
    100 FORMAT(/A)
    !
    120 FORMAT(/ ' Current Rotor at Disk', I3, &
            / '  Omega  ', F12.4, '    Rpm    ', F11.2, &
            / '  Rhub   ', F12.5, '    Rtip   ', F11.5, &
            / '  #blades', I6, 6X, '    Aswept ', F11.5)
    200 FORMAT('     r         r/R        Ch      Beta(deg)   Solidity')
    210 FORMAT(1X, 7G11.4)
    !

    RETURN
END
! SHOWBLADE


SUBROUTINE SHOWDRAGOBJ(ND, LU)
    !-------------------------------------------------------
    !     Displays parameters on drag objects
    !-------------------------------------------------------
    INCLUDE 'DFDC.inc'
    !
    IF(NDOBJ.LE.0) THEN
        WRITE(LU, *)
        WRITE(LU, *) 'No drag objects defined'
        RETURN
    ENDIF
    !
    IF(ND.LE.0) THEN
        ND1 = 1
        ND2 = NDOBJ
        WRITE(LU, 120) NDOBJ
    ELSE
        ND1 = ND
        ND2 = ND
    ENDIF
    !
    DO N = ND1, ND2
        WRITE(LU, 130) N
        WRITE(LU, 200)
        !
        DO ID = 1, NDDEF(N)
            WRITE(LU, 210) ID, XDDEF(ID, N), YDDEF(ID, N), CDADEF(ID, N)
        END DO
        !
    END DO
    !
    100 FORMAT(/A)
    110 FORMAT(' QINF  =', F12.4, &
            /' QREF  =', F12.4, &
            /' OMEGA =', F12.4, &
            /' RPM   =', F12.4)
    !
    120 FORMAT(/, I2, ' Drag Area objects defined:', /)
    130 FORMAT(' Drag Area', I3)
    200 FORMAT('    i        x          r        CDave')
    !             a1234567890112345678901123456789011234567890112345678901
    210 FORMAT(I5, F11.4, F11.4, 3X, G11.4)
    !
    RETURN
END
! SHOWDRAGOBJ


SUBROUTINE SETDRGOBJSRC
    !-------------------------------------------------------
    !     Sets source strength for rotor drag and drag objects
    !-------------------------------------------------------
    INCLUDE 'DFDC.inc'
    DIMENSION VDM(IRX), T1(IRX), T1S(IRX)
    !
    !---- Set sources for drag objects
    IF(NDOBJ.LE.0) THEN
        !c        WRITE(*,*) 'Drag objects not defined'
        RETURN
        !
    ELSE
        !---- step through all defined drag objects
        DO N = 1, NDOBJ
            !
            IF(IELDRGOBJ(N).LE.0) THEN
                WRITE(*, *) 'Source element not defined for drag object ', N
                STOP
            ENDIF
            !
            !---- if drag objects are turned off clear the source strengths
            IF(.NOT.LDRGOBJ) THEN
                IEL = IELDRGOBJ(N)
                IP1 = IPFRST(IEL)
                IP2 = IPLAST(IEL)
                DO IP = IP1, IP2
                    SIGVSP(IP) = 0.0
                END DO
                !
            ELSE
                !
                !---- Set up spline arrays for drag object
                IF(NDDEF(N).GE.2) THEN
                    DO I = 1, NDDEF(N)
                        T1(I) = CDADEF(I, N)
                    END DO
                    !---- Spline drag definition array
                    CALL SEGSPL(T1, T1S, YDDEF(1, N), NDDEF(N))
                    !
                    IEL = IELDRGOBJ(N)
                    IC1 = ICFRST(IEL)
                    IC2 = ICLAST(IEL)
                    IP1 = IPFRST(IEL)
                    IP2 = IPLAST(IEL)
                    !
                    DO IC = IC1, IC2
                        VXX = QC(1, IC)
                        VRR = QC(2, IC)
                        ID = IC - IC1 + 1
                        VDM(ID) = SQRT(VXX**2 + VRR**2)
                    END DO
                    !
                    DO IP = IP1, IP2
                        YY = YP(IP)
                        CDAV = SEVAL(YY, T1, T1S, YDDEF(1, N), NDDEF(N))
                        ID = IP - IP1 + 1
                        IF(IP.EQ.IP1) THEN
                            SIGVSP(IP) = 0.5 * VDM(ID) * CDAV
                        ELSEIF(IP.EQ.IP2) THEN
                            SIGVSP(IP) = 0.5 * VDM(ID - 1) * CDAV
                        ELSE
                            SIGVSP(IP) = 0.25 * (VDM(ID) + VDM(ID - 1)) * CDAV
                        ENDIF
                        !c          WRITE(*,99) 'IP,CDAV,SIGVSP ',IP,CDAV,SIGVSP(IP)
                    END DO
                ENDIF
                !
            ENDIF
            !
        END DO
    ENDIF
    !
    99   FORMAT(A, I4, 5(1X, F11.5))
    !
    RETURN
END
! SETDRGOBJSRC



SUBROUTINE SETROTORSRC
    !-------------------------------------------------------
    !     Sets source strength for rotor profile drag
    !-------------------------------------------------------
    INCLUDE 'DFDC.inc'
    DIMENSION VDM(IRX), T1(IRX), T1S(IRX)
    !
    DO N = 1, NROTOR
        !---- Set sources for rotor drag
        IF(IELROTOR(N).LE.0) THEN
            !c        WRITE(*,*) 'Rotor source line not defined'
            !c         RETURN
        ELSE
            !
            IEL = IELROTOR(N)
            IC1 = ICFRST(IEL)
            IC2 = ICLAST(IEL)
            IP1 = IPFRST(IEL)
            IP2 = IPLAST(IEL)
            BLDS = FLOAT(NRBLD(N))
            !
            DO IC = IC1, IC2
                VXX = QC(1, IC)
                VRR = QC(2, IC)
                VMM = SQRT(VXX**2 + VRR**2)
                IR = IC - IC1 + 1
                VTT = 0.5 * BGAM(IR, N) * PI2I / YC(IC) - OMEGA(N) * YC(IC)
                VDM(IR) = SQRT(VMM**2 + VTT**2)
            END DO
            !
            DO IP = IP1, IP2
                IR = IP - IP1 + 1
                IF(IP.EQ.IP1) THEN
                    SIGVSP(IP) = 0.5 * BLDS * PI2I * VDM(IR) * CHR(IR, N) * CDR(IR, N)
                    !c         WRITE(*,99) 'IP,W,CD,SIGVSP ',IP,VDM(IR),CDR(IR),SIGVSP(IP)
                ELSEIF(IP.EQ.IP2) THEN
                    !---- NOTE: should set tip source to 0.0 for tip gap (no blade defined here)
                    SIGVSP(IP) = 0.5 * BLDS * PI2I * VDM(IR - 1) * CHR(IR - 1, N) * CDR(IR - 1, N)
                    !c         WRITE(*,99) 'IP,W,CD,SIGVSP ',IP,VDM(IR-1),CDR(IR-1),SIGVSP(IP)
                ELSE
                    VAVE = 0.5 * (VDM(IR) + VDM(IR - 1))
                    CDAVE = 0.5 * (CDR(IR, N) + CDR(IR - 1, N))
                    CHAVE = 0.5 * (CHR(IR, N) + CHR(IR - 1, N))
                    SIGVSP(IP) = 0.5 * BLDS * PI2I * VAVE * CHAVE * CDAVE
                    !c         WRITE(*,99) 'IP,W,CD,SIGVSP ',IP,VAVE,CDAVE,SIGVSP(IP)
                ENDIF
            END DO
        ENDIF
        !
    END DO
    !
    99   FORMAT(A, I4, 5(1X, F11.5))
    !
    RETURN
END
! SETROTORSRC



SUBROUTINE VMAVGINIT(VAXIAL)
    !---------------------------------------------------------
    !     Initializes VMAVG using axial velocity estimate
    !---------------------------------------------------------
    INCLUDE 'DFDC.inc'
    !
    IF(LDBG) THEN
        WRITE(*, *)      'VMAVGINIT called with VA=', VAXIAL
        WRITE(LUNDBG, *) 'VMAVGINIT called with VA=', VAXIAL
    ENDIF
    !
    !---- Set VMAVG on all wake element points
    DO IR = 1, NRP
        IEL = IR2IEL(IR)
        !c      IC1 = ICFRST(IEL)
        !c      IC2 = ICLAST(IEL)
        IP1 = IPFRST(IEL)
        IP2 = IPLAST(IEL)
        DO IP = IP1, IP2
            IF(IR.EQ.1) THEN
                VMAVG(IP) = 0.5 * (VAXIAL + QINF)
            ELSEIF(IR.EQ.NRP) THEN
                VMAVG(IP) = 0.5 * (VAXIAL + QINF)
            ELSE
                VMAVG(IP) = VAXIAL
            ENDIF
        END DO
    END DO
    !
    !---- Set VMAVG on CB body wake points
    !      IEL = 1
    !      IC1 = ICFRST(IEL)
    !      IC2 = ICLAST(IEL)
    !      DO IC = IC1, IC2
    !        IP1 = IPCO(IC)
    !        IP2 = IPCP(IC)
    !        IF(IP2IR(IP1).NE.0 .AND. IP2IR(IP2).NE.0) THEN
    !          VMAVG(IP1) = 0.5*(VAXIAL+QINF)
    !          VMAVG(IP2) = 0.5*(VAXIAL+QINF)
    !        ENDIF
    !      END DO
    !
    !---- Set VMAVG on duct body wake points
    !      IEL = 2
    !      IC1 = ICFRST(IEL)
    !      IC2 = ICLAST(IEL)
    !      DO IC = IC2, IC1, -1
    !        IP1 = IPCO(IC)
    !        IP2 = IPCP(IC)
    !        IF(IP2IR(IP1).NE.0 .AND. IP2IR(IP2).NE.0) THEN
    !          VMAVG(IP1) = 0.5*(VAXIAL+QINF)
    !          VMAVG(IP2) = 0.5*(VAXIAL+QINF)
    !        ENDIF
    !      END DO
    !
    IF(LDBG) THEN
        WRITE(LUNDBG, *)  'At end of VMAVGINIT'
        DO IEL = 1, NEL
            !         IF(NETYPE(IEL).EQ.7) THEN
            IC1 = ICFRST(IEL)
            IC2 = ICLAST(IEL)
            WRITE(LUNDBG, *)  IEL, IC1, IC2
            DO IC = IC1, IC2
                IP1 = IPCO(IC)
                IP2 = IPCP(IC)
                WRITE(LUNDBG, *)  'IP1,VMavg ', IP1, VMAVG(IP1)
                WRITE(LUNDBG, *)  'IP2,VMavg ', IP2, VMAVG(IP2)
            END DO
            !        ENDIF
        END DO
    ENDIF
    20   FORMAT(A, I5, 5(1X, F10.4))
    !
    LVMAV = .TRUE.
    !
    RETURN
END
! VMAVGINIT


SUBROUTINE VMAVGCALC
    !---------------------------------------------------------
    !     Calculates VMAVG at rotor wake points using current
    !     center point velocities QC(1,.), QC(2,.)
    !---------------------------------------------------------
    INCLUDE 'DFDC.inc'
    !
    IF(LDBG) THEN
        WRITE(*, *)      'Entering VMAVGCALC'
        WRITE(LUNDBG, *) 'Entering VMAVGCALC'
    ENDIF
    !
    !---- Set VMAVG on all wake points, first and last set from centers
    !     intermediate points get average from nearby panel centers
    DO IEL = 1, NEL
        IF(NETYPE(IEL).EQ.7) THEN
            IC1 = ICFRST(IEL)
            IC2 = ICLAST(IEL)
            DO IC = IC1, IC2
                IP1 = IPCO(IC)
                IP2 = IPCP(IC)
                !           IF(IEL.NE.IR2IEL(1)) THEN
                QCX = QC(1, IC)
                QCY = QC(2, IC)
                !           ELSE
                !             QCX = 0.5*QCL(1,IC)
                !             QCY = 0.5*QCL(2,IC)
                !           ENDIF
                VMAV = SQRT(QCX**2 + QCY**2)
                !---- limiter to keep VMAV positive (to fraction of QREF)
                VMAV = MAX(0.1 * QREF, VMAV)
                IF(IC.EQ.IC1) THEN
                    VMAVG(IP1) = VMAV
                ELSE
                    VMAVG(IP1) = 0.5 * (VMAVG(IP1) + VMAV)
                ENDIF
                VMAVG(IP2) = VMAV
            END DO
        ENDIF
    END DO
    !
    !---- Set VMAVG on CB body vortex wake points
    !      IEL = 1
    !      IR  = 1
    !      IC1 = ICFRST(IEL)
    !      IC2 = ICLAST(IEL)
    !      DO IC = IC1, IC2
    !        IP1 = IPCO(IC)
    !        IP2 = IPCP(IC)
    !        IF(IP2IR(IP1).EQ.IR .AND. IP2IR(IP2).EQ.IR) THEN
    !c         write(77,*) 'iel,ic,ir ',iel,ic,ir
    !         QCX = QC(1,IC)
    !         QCY = QC(2,IC)
    !         VMAV = SQRT(QCX**2 + QCY**2)
    !         IF(IC.EQ.IC1) THEN
    !          VMAVG(IP1) = VMAV
    !         ELSE
    !          VMAVG(IP1) = 0.5*VMAVG(IP1) + 0.5*VMAV
    !         ENDIF
    !         VMAVG(IP2) = VMAV
    !c         write(77,*) 'ip1,vmavg ',ip1,vmavg(ip1)
    !c         write(77,*) 'ip2,vmavg ',ip2,vmavg(ip2)
    !        ENDIF
    !      END DO
    !---- Average velocities on CB TE and wake upstream point
    !      IPB = IPFRST(IEL)
    !      IPW = IPFRST(IR2IEL(IR))
    !      VMAV = 0.5*(VMAVG(IPB) + VMAVG(IPW))
    !      VMAVG(IPB) = VMAV
    !      VMAVG(IPW) = VMAV
    !
    !---- Set VMAVG on duct body vortex wake points
    !      IEL = 2
    !      IR  = NRP
    !      IC1 = ICFRST(IEL)
    !      IC2 = ICLAST(IEL)
    !      DO IC = IC2, IC1, -1
    !        IP1 = IPCO(IC)
    !        IP2 = IPCP(IC)
    !        IF(IP2IR(IP1).EQ.IR .AND. IP2IR(IP2).EQ.IR) THEN
    !         QCX = QC(1,IC)
    !         QCY = QC(2,IC)
    !         VMAV = SQRT(QCX**2 + QCY**2)
    !         IF(IC.EQ.IC2) THEN
    !          VMAVG(IP2) = VMAV
    !         ELSE
    !          VMAVG(IP2) = 0.5*VMAVG(IP1) + 0.5*VMAV
    !         ENDIF
    !         VMAVG(IP1) = VMAV
    !        ENDIF
    !      END DO
    !---- Average velocities on duct TE and wake upstream point
    !      IPB = IPLAST(IEL)
    !      IPW = IPFRST(IR2IEL(IR))
    !      VMAV = 0.5*(VMAVG(IPB) + VMAVG(IPW))
    !      VMAVG(IPB) = VMAV
    !      VMAVG(IPW) = VMAV
    !

    IF(LDBG) THEN
        WRITE(LUNDBG, *)  'At end of VMAVGCALC'
        DO IEL = 1, NEL
            !          IF(NETYPE(IEL).EQ.7) THEN
            IC1 = ICFRST(IEL)
            IC2 = ICLAST(IEL)
            WRITE(LUNDBG, *) 'IEL,IC1,IC2,IPFRST(IEL),IPLAST(IEL)'
            WRITE(LUNDBG, *)  IEL, IC1, IC2, IPFRST(IEL), IPLAST(IEL)
            DO IC = IC1, IC2
                IP1 = IPCO(IC)
                IP2 = IPCP(IC)
                WRITE(LUNDBG, *)  'IP1,VMavg ', IP1, VMAVG(IP1)
                WRITE(LUNDBG, *)  'IP2,VMavg ', IP2, VMAVG(IP2)
            END DO
            !          ENDIF
        END DO
    ENDIF
    20   FORMAT(A, I5, 5(1X, F10.4))
    !
    !c      LVMAV = .TRUE.
    !
    RETURN
END
! VMAVGCALC




SUBROUTINE GTHCALC(GAMTH)
    !---------------------------------------------------------
    !     Calculates GTH at rotor wake points using zero
    !     pressure jump relation
    !   Note: this formulation sets GTH on endpoints using
    !         center velocity (not averaged VM at endpoints)
    !
    !---------------------------------------------------------
    INCLUDE 'DFDC.inc'
    DIMENSION GAMTH(IPX)
    !
    IF(LDBG) WRITE(*, *) 'Entering GTHCALC'
    !
    DO IP = 1, NPTOT
        GAMTH(IP) = 0.0
    END DO
    !
    !---- Set GAMTH on intermediate wakes
    DO IR = 2, NRP - 1
        IEL = IR2IEL(IR)
        IC1 = ICFRST(IEL)
        IC2 = ICLAST(IEL)
        DO IC = IC1, IC2
            IP1 = IPCO(IC)
            IP2 = IPCP(IC)
            IG = IC2IG(IC)
            DH = DHG(IG, IR) - DHG(IG, IR - 1)
            DG = 0.5 * PI2I**2 * (BGAMG(IG, IR)**2 - BGAMG(IG, IR - 1)**2)
            IF(VMAVG(IP1).NE.0.0) THEN
                GAMTH(IP1) = (DH - DG / (YP(IP1)**2)) / VMAVG(IP1)
            ELSE
                !            WRITE(*,*) 'Zero VMavg on IP1 =',IP1,VMAVG(IP1)
                GAMTH(IP1) = 0.
            ENDIF
            IF(VMAVG(IP2).NE.0.0) THEN
                GAMTH(IP2) = (DH - DG / (YP(IP2)**2)) / VMAVG(IP2)
            ELSE
                !            WRITE(*,*) 'Zero VMavg on IP2 =',IP2,VMAVG(IP2)
                GAMTH(IP2) = 0.
            ENDIF
        END DO
    END DO
    !
    !---- Set GAMTH on CB wake
    IR = 1
    IEL = IR2IEL(IR)
    IC1 = ICFRST(IEL)
    IC2 = ICLAST(IEL)
    DO IC = IC1, IC2
        IP1 = IPCO(IC)
        IP2 = IPCP(IC)
        IG = IC2IG(IC)
        DH = 0.0
        !c        DH =                DHG(IG,IR)
        DG = 0.5 * PI2I**2 * (BGAMG(IG, IR)**2)
        IF(VMAVG(IP1).NE.0.0) THEN
            GAMTH(IP1) = (DH - DG / (YP(IP1)**2)) / VMAVG(IP1)
        ELSE
            WRITE(*, *) 'Zero VMavg on CB wake IP1 =', IP1, VMAVG(IP1)
            GAMTH(IP1) = 0.
        ENDIF
        IF(VMAVG(IP2).NE.0.0) THEN
            GAMTH(IP2) = (DH - DG / (YP(IP2)**2)) / VMAVG(IP2)
        ELSE
            WRITE(*, *) 'Zero VMavg on CB wake IP2 =', IP2, VMAVG(IP2)
            GAMTH(IP2) = 0.
        ENDIF
    END DO
    !
    !---- Set GTH on CB to value at first wake point
    IR = 1
    IEL = IR2IEL(IR)
    IP1 = IPFRST(IEL)
    GTH1 = GAMTH(IP1)
    Y1 = YP(IP1)
    IEL = 1
    IC1 = ICFRST(IEL)
    IC2 = ICLAST(IEL)
    DO IC = IC1, IC2
        IP1 = IPCO(IC)
        IP2 = IPCP(IC)
        IF(IP2IR(IP1).EQ.IR .AND. IP2IR(IP2).EQ.IR) THEN
            GAMTH(IP1) = 0.0
            GAMTH(IP2) = 0.0
            !---- taper off the GTH on CB from GTH at TE to 0.0 at rotor
            FRAC = 1.0 - FLOAT(IP1 - IPFRST(IEL)) / FLOAT(IPROTCB(1))
            GAMTH(IP1) = GTH1 * FRAC
            FRAC = 1.0 - FLOAT(IP2 - IPFRST(IEL)) / FLOAT(IPROTCB(1))
            GAMTH(IP2) = GTH1 * FRAC
        ENDIF
        !
    END DO
    !
    !---- Set GAMTH on DUCT wake
    IR = NRP
    IEL = IR2IEL(IR)
    IC1 = ICFRST(IEL)
    IC2 = ICLAST(IEL)
    DO IC = IC1, IC2
        IP1 = IPCO(IC)
        IP2 = IPCP(IC)
        IG = IC2IG(IC)
        DH = - DHG(IG, IR - 1)
        DG = 0.5 * PI2I**2 * (- BGAMG(IG, IR - 1)**2)
        IF(VMAVG(IP1).NE.0.0) THEN
            GAMTH(IP1) = (DH - DG / (YP(IP1)**2)) / VMAVG(IP1)
        ELSE
            WRITE(*, *) 'Zero VMavg on duct wake IP1 =', IP1, VMAVG(IP1)
            GAMTH(IP1) = 0.
        ENDIF
        IF(VMAVG(IP2).NE.0.0) THEN
            GAMTH(IP2) = (DH - DG / (YP(IP2)**2)) / VMAVG(IP2)
        ELSE
            WRITE(*, *) 'Zero VMavg on duct wake IP2 =', IP2, VMAVG(IP2)
            GAMTH(IP2) = 0.
        ENDIF
    END DO
    !
    !---- Set GAMTH on DUCT from first wake GAMTH
    IR = NRP
    IEL = IR2IEL(IR)
    IP1 = IPFRST(IEL)
    GTH1 = GAMTH(IP1)
    Y1 = YP(IP1)
    IEL = 2
    IC1 = ICFRST(IEL)
    IC2 = ICLAST(IEL)
    DO IC = IC1, IC2
        IP1 = IPCO(IC)
        IP2 = IPCP(IC)
        IF(IP2IR(IP1).EQ.IR .AND. IP2IR(IP2).EQ.IR) THEN
            !          GAMTH(IP1) = 0.0
            !          GAMTH(IP2) = 0.0
            !          GAMTH(IP1) = GTH1
            !          GAMTH(IP2) = GTH1
            !---- taper off the GTH on duct from GTH at TE to 0.0 at rotor
            FRAC = 1.0 - FLOAT(IPLAST(IEL) - IP1) / &
                    FLOAT(IPLAST(IEL) - IPROTDW(1) + 1)
            GAMTH(IP1) = GTH1 * FRAC
            FRAC = 1.0 - FLOAT(IPLAST(IEL) - IP2) / &
                    FLOAT(IPLAST(IEL) - IPROTDW(1) + 1)
            GAMTH(IP2) = GTH1 * FRAC
        ENDIF
        !
    END DO
    !
    !
    IF(LDBG) THEN
        WRITE(LUNDBG, *)  'At end of GTHCALC'
        DO IEL = 1, NEL
            IC1 = ICFRST(IEL)
            IC2 = ICLAST(IEL)
            WRITE(LUNDBG, *) 'IEL,IC1,IC2,IPFRST(IEL),IPLAST(IEL)'
            WRITE(LUNDBG, *)  IEL, IC1, IC2, IPFRST(IEL), IPLAST(IEL)
            DO IC = IC1, IC2
                IP1 = IPCO(IC)
                IP2 = IPCP(IC)
                WRITE(LUNDBG, *)  'IP1,GAMTH ', IP1, GAMTH(IP1)
                WRITE(LUNDBG, *)  'IP2,GAMTH ', IP2, GAMTH(IP2)
            END DO
        END DO
    ENDIF
    20   FORMAT(A, I5, 5(1X, F10.4))
    !
    RETURN
END
! GTHCALC





SUBROUTINE TQCALC(ITYPE)
    INCLUDE 'DFDC.inc'
    !----------------------------------------------------------
    !     Sets Thrust, Torque and their sensitivities
    !     wrt  QINF, OMEGA, BETA, chord(i), VA,VT, BGAM
    !----------------------------------------------------------
    !
    !---- total forces accumulation
    TTOT = 0.
    TVIS = 0.
    QTOT = 0.
    QVIS = 0.
    PTOT = 0.
    PVIS = 0.
    !
    DO 2000 N = 1, NROTOR
        !
        !---- forces on blade row
        TINVR(N) = 0.
        QINVR(N) = 0.
        TI_OMG(N) = 0.
        QI_OMG(N) = 0.
        TI_QNF(N) = 0.
        QI_QNF(N) = 0.
        !
        TVISR(N) = 0.
        QVISR(N) = 0.
        TV_OMG(N) = 0.
        QV_OMG(N) = 0.
        TV_QNF(N) = 0.
        QV_QNF(N) = 0.
        TV_DBE(N) = 0.
        QV_DBE(N) = 0.
        !
        DO I = 1, NRC
            TI_GAM(I, N) = 0.
            TI_VA (I, N) = 0.
            TI_VT (I, N) = 0.
            QI_GAM(I, N) = 0.
            QI_VA (I, N) = 0.
            QI_VT (I, N) = 0.
            TV_GAM(I, N) = 0.
            TV_VA (I, N) = 0.
            TV_VT (I, N) = 0.
            QV_GAM(I, N) = 0.
            QV_VA (I, N) = 0.
            QV_VT (I, N) = 0.
        ENDDO
        !
        !c      write(*,*) 'LBLDEF ',LBLDEF
        CALL ROTORVABS(N, VIND(1, 1, N))
        !
        !---- go over radial stations, setting thrust and torque
        !
        !---- NOTE: should only go over blade stations to NRC-1 for tip gap case
        !
        BLDS = FLOAT(NRBLD(N))
        DO 1000 I = 1, NRC
            !
            !---- Skip forces for tip gap (only on rotor)
            IF(I.EQ.NRC .AND. TGAP.GT.0.0 .AND. OMEGA(N).NE.0.0) THEN
                CLR(NRC, N) = 0.0
                CDR(NRC, N) = 0.0
                ALFAR(NRC, N) = 0.0
                GO TO 1000
            ENDIF
            !
            XI = YRC(I, N) / RTIP(N)
            RA = 0.5 * (YRP(I + 1, N) + YRP(I, N))
            DR = YRP(I + 1, N) - YRP(I, N)
            RDR = YRC(I, N) * DR
            BDR = BLDS * DR
            BRDR = BLDS * RDR
            DA = PI * RA * DR
            !
            !------ set  W(Qinf,Omeg,Va,Vt)  and  Phi(Qinf,Omeg,Va,Vt)  sensitivities
            CALL WCALC(N, I, VAINF, VTINF, &
                    VTT, &
                    VAA, &
                    CI, CI_OMG, CI_VT, &
                    SI, SI_QNF, SI_VA, &
                    W, W_OMG, W_QNF, W_VT, W_VA, &
                    PHIB, P_OMG, P_QNF, P_VT, P_VA)
            !
            ALFA = BETAR(I, N) - PHIB
            AL_DBE = 1.0
            AL_P = -1.0
            !
            !---- Set local Mach number in relative frame
            MACHR(I, N) = W / VSO
            !
            !
            !---- Check for rotor type, actuator disk or blade row
            !     If no blade has been defined an inviscid thrust and torque
            !     calculation will be made for the actuator disk using circulation.
            !     Otherwise blade element theory will be used to calculate forces
            !     on the blades using aerodynamic characteristics for the blade elements.
            !
            IF(IRTYPE(N).EQ.2) THEN
                !
                IF(ITYPE.EQ.1) THEN
                    !------- analysis case:  fix local Beta (except for pitch change)
                    !------- set alfa(Gi,dBeta,Qinf,Omeg,Va,Vt) sensitivites
                    ALFA = BETAR(I, N) - PHIB
                    ALFAR(I, N) = ALFA
                    AL_GI = 0.
                    AL_DBE = 1.0
                    AL_OMG = -P_OMG
                    AL_QNF = -P_QNF
                    AL_VT = -P_VT
                    AL_VA = -P_VA
                    !
                    !------- set CL(Gi,dBeta,Qinf,Omeg,Va,Vt) sensitivites
                    REY = CHR(I, N) * ABS(W) * RHO / RMU
                    SECSIG = BLDS * CHR(I, N) / (2.0 * PI * YRC(I, N))
                    SECSTAGR = 0.5 * PI - BETAR(I, N)
                    CALL GETCLCDCM(N, I, XI, ALFA, W, REY, SECSIG, SECSTAGR, &
                            CLR(I, N), CL_AL, CL_W, &
                            CLMAX, CLMIN, DCLSTALL, LSTALLR(I, N), &
                            CDR(I, N), CD_ALF, CD_W, CD_REY, &
                            CMR(I, N), CM_AL, CM_W)
                    CLALF(I, N) = CL_AL
                    CL_GI = CL_AL * AL_GI
                    CL_DBE = CL_AL * AL_DBE
                    CL_OMG = CL_AL * AL_OMG + CL_W * W_OMG
                    CL_QNF = CL_AL * AL_QNF + CL_W * W_QNF
                    CL_VT = CL_AL * AL_VT + CL_W * W_VT
                    CL_VA = CL_AL * AL_VA + CL_W * W_VA
                    !
                    !------- set c(Gi,Qinf,Omeg,Va,Vt) sensitivites  (chord is fixed)
                    CH_GI = 0.
                    CH_OMG = 0.
                    CH_QNF = 0.
                    CH_VT = 0.
                    CH_VA = 0.
                    !
                ELSE IF(ITYPE.EQ.2) THEN
                    !---- design case:  fix local CL and set chord based on circulation
                    !---- update design CL arrays
                    !
                    IF(OMEGA(N).GT.0.0)THEN
                        DO J = 1, NRC
                            CLDES(J) = CLPOS(J)
                        ENDDO
                    ELSE
                        DO J = 1, NRC
                            CLDES(J) = CLNEG(J)
                        ENDDO
                    ENDIF
                    !
                    !------- set alfa(Gi,dBeta,Adv,Adw,Vt) sensitivites
                    CLR(I, N) = CLDES(I)
                    !
                    SECSIG = BLDS * CHR(I, N) / (2.0 * PI * YRC(I, N))
                    SECSTAGR = 0.5 * PI - BETAR(I, N)
                    CALL GETALF(N, I, XI, SECSIG, SECSTAGR, &
                            CLR(I, N), W, ALFA, AL_CL, AL_W, LSTALLR(I, N))
                    !c         write(*,*) 'tq2 getalf i,cl,w,alf ',i,clr(i),w,alfa/dtr
                    !
                    AL_GI = 0.
                    AL_DBE = 0.
                    AL_OMG = AL_W * W_OMG
                    AL_QNF = AL_W * W_QNF
                    AL_VT = AL_W * W_VT
                    AL_VA = AL_W * W_VA
                    !
                    !------- set CL(Gi,dBeta,Adv,Adw,Vt) sensitivites
                    CL_GI = 0.
                    CL_DBE = 0.
                    CL_OMG = 0.
                    CL_QNF = 0.
                    CL_VT = 0.
                    CL_VA = 0.
                    !
                    !------- set c(Gi,Adv,Adw,Vt) sensitivites
                    CHNEW = 2.0 * BGAM(I, N) / (BLDS * W * CLR(I, N))
                    !--- Check for chord going zero or negative and use nearby station data
                    !    for this iteration
                    IF(CHNEW.LE.0.0) THEN
                        !c           write(*,*) 'TQCALC negative chord @I = ',I,CHNEW
                        IF(I.EQ.1) THEN
                            CHR(I, N) = CHR(I + 1, N)
                        ELSEIF(I.EQ.II) THEN
                            CHR(I, N) = CHR(I - 1, N)
                        ELSE
                            CHR(I, N) = 0.5 * (CHR(I - 1, N) + CHR(I + 1, N))
                        ENDIF
                        CH_GI = 0.0
                        CH_OMG = 0.0
                        CH_QNF = 0.0
                        CH_VT = 0.0
                        CH_VA = 0.0
                    ELSE
                        CHR(I, N) = 2.0 * BGAM(I, N) / (BLDS * W * CLR(I, N))
                        !c          write(*,*) 'tq2 bgam,cl,ch ',bgam(i,n),clr(i,n),chr(i,n)
                        CH_GI = 2.0 / (BLDS * W * CLR(I, N))
                        CH_OMG = (-CHR(I, N) / W) * W_OMG
                        CH_QNF = (-CHR(I, N) / W) * W_QNF
                        CH_VT = (-CHR(I, N) / W) * W_VT
                        CH_VA = (-CHR(I, N) / W) * W_VA
                    ENDIF
                    !
                    BETAR(I, N) = ALFA + PHIB
                    ALFAR(I, N) = ALFA
                    !
                ELSE IF(ITYPE.EQ.3) THEN
                    !------- design case:  fix local chord and set angles based on CL
                    !
                    !------- set CL(Gi,dBeta,Adv,Adw,Vt) sensitivites
                    CLR(I, N) = 2.0 * BGAM(I, N) / (BLDS * W * CHR(I, N))
                    CL_GI = 2.0 / (BLDS * W * CHR(I, N))
                    CL_DBE = 0.
                    CL_OMG = (-CLR(I, N) / W) * W_OMG
                    CL_QNF = (-CLR(I, N) / W) * W_QNF
                    CL_VT = (-CLR(I, N) / W) * W_VT
                    CL_VA = (-CLR(I, N) / W) * W_VA
                    !
                    !------- set alfa(Gi,dBeta,Adv,Adw,Vt) sensitivites
                    SECSIG = BLDS * CHR(I, N) / (2.0 * PI * YRC(I, N))
                    SECSTAGR = 0.5 * PI - BETAR(I, N)
                    CALL GETALF(N, I, XI, SECSIG, SECSTAGR, &
                            CLR(I, N), W, ALFA, AL_CL, AL_W, LSTALLR(I, N))
                    !c         write(*,*) 'tq3 i,cl,ch,w,alf ',i,clr(i),chr(i),w,alfa/dtr
                    AL_GI = AL_CL * CL_GI
                    AL_DBE = AL_CL * CL_DBE
                    AL_OMG = AL_CL * CL_OMG + AL_W * W_OMG
                    AL_QNF = AL_CL * CL_QNF + AL_W * W_QNF
                    AL_VT = AL_CL * CL_VT + AL_W * W_VT
                    AL_VA = AL_CL * CL_VA + AL_W * W_VA
                    !
                    !------- set c(Gi,Adv,Adw,Vt) sensitivites
                    CH_GI = 0.
                    CH_OMG = 0.
                    CH_QNF = 0.
                    CH_VT = 0.
                    CH_VA = 0.
                    !
                    BETAR(I, N) = ALFA + PHIB
                    ALFAR(I, N) = ALFA
                    !
                ENDIF
                !
                !
                !=================================================================
                !
                RER(I, N) = CHR(I, N) * ABS(W) * RHO / RMU
                RE_W = CHR(I, N) * RHO / RMU
                RE_CH = ABS(W) * RHO / RMU
                !
                !------ set Re(Gi,Adv,Adw,Vt) sensitivites
                RE_GI = RE_CH * CH_GI
                RE_OMG = RE_CH * CH_OMG + RE_W * W_OMG
                RE_QNF = RE_CH * CH_QNF + RE_W * W_QNF
                RE_VT = RE_CH * CH_VT + RE_W * W_VT
                RE_VA = RE_CH * CH_VA + RE_W * W_VA
                !
                !------ set CM and (not used at present) sensitivites
                !------ set CD(Gi,dBeta,Adv,Adw,Vt) sensitivites
                SECSIG = BLDS * CHR(I, N) / (2.0 * PI * YRC(I, N))
                SECSTAGR = 0.5 * PI - BETAR(I, N)
                CALL GETCLCDCM(N, I, XI, ALFA, W, RER(I, N), SECSIG, SECSTAGR, &
                        CLR(I, N), CL_AL, CL_W, &
                        CLMAX, CLMIN, DCLSTALL, LSTALLR(I, N), &
                        CDR(I, N), CD_AL, CD_W, CD_RE, &
                        CMR(I, N), CM_AL, CM_W)
                CLALF(I, N) = CL_AL
                !c        write(*,97) 'tqcalc alfa,cl,cd,cm ',i,alfa,clr(i),cdr(i)
                97     format(A, I5, 5(1x, F12.6))
                CD_GI = CD_AL * AL_GI + CD_RE * RE_GI
                CD_OMG = CD_AL * AL_OMG + CD_RE * RE_OMG + CD_W * W_OMG
                CD_QNF = CD_AL * AL_QNF + CD_RE * RE_QNF + CD_W * W_QNF
                CD_VT = CD_AL * AL_VT + CD_RE * RE_VT + CD_W * W_VT
                CD_VA = CD_AL * AL_VA + CD_RE * RE_VA + CD_W * W_VA
                CD_DBE = CD_AL * AL_DBE
                !
                !
                HRWC = 0.5 * RHO * W * CHR(I, N)
                HRWC_W = 0.5 * RHO * CHR(I, N)
                HRWC_CH = 0.5 * RHO * W
                !
                !*******************************************************
                !------ Viscous Thrust & Power contributions on real prop
                !
                !------ dTv ( Cd , S , W , c ) sensitivites
                DTV = -HRWC * CDR(I, N) * SI * BDR
                !
                DTV_CD = -HRWC * SI * BDR
                DTV_SI = -HRWC * CDR(I, N) * BDR
                DTV_W = -HRWC_W * CDR(I, N) * SI * BDR
                DTV_CH = -HRWC_CH * CDR(I, N) * SI * BDR
                !
                !------ set Tv(Gi,dBeta,Adv,Vt) sensitivites using chain rule
                DTV_GI = DTV_CD * CD_GI + DTV_CH * CH_GI
                DTV_DBE = DTV_CD * CD_DBE
                DTV_OMG = DTV_CD * CD_OMG + DTV_CH * CH_OMG&
                        + DTV_W * W_OMG
                DTV_QNF = DTV_CD * CD_QNF + DTV_CH * CH_QNF&
                        + DTV_W * W_QNF
                DTV_VT = DTV_CD * CD_VT + DTV_CH * CH_VT&
                        + DTV_W * W_VT
                DTV_VA = DTV_CD * CD_VA + DTV_CH * CH_VA&
                        + DTV_SI * SI_VA + DTV_W * W_VA
                !
                !------ accumulate viscous Thrust and sensitivities
                TVISR(N) = TVISR(N) + DTV
                TV_OMG(N) = TV_OMG(N) + DTV_OMG
                TV_QNF(N) = TV_QNF(N) + DTV_QNF
                TV_DBE(N) = TV_DBE(N) + DTV_DBE
                !
                TV_GAM(I, N) = DTV_GI
                TV_VA (I, N) = DTV_VA
                TV_VT (I, N) = DTV_VT
                !
                !
                !------ dQv( Cd , C , W , c )
                DQV = -HRWC * CDR(I, N) * CI * BRDR
                !
                DQV_CD = -HRWC * CI * BRDR
                DQV_CI = -HRWC * CDR(I, N) * BRDR
                DQV_W = -HRWC_W * CDR(I, N) * CI * BRDR
                DQV_CH = -HRWC_CH * CDR(I, N) * CI * BRDR
                DQV_OM = -HRWC * CDR(I, N) * CI * BRDR
                !
                !------ set Pv(Gi,dBeta,Adv,Vt) sensitivites using chain rule
                DQV_GI = DQV_CD * CD_GI + DQV_CH * CH_GI
                DQV_DBE = DQV_CD * CD_DBE
                DQV_OMG = DQV_OM&
                        + DQV_CD * CD_OMG + DQV_CH * CH_OMG&
                        + DQV_CI * CI_OMG + DQV_W * W_OMG
                DQV_QNF = DQV_CD * CD_QNF + DQV_CH * CH_QNF&
                        + DQV_W * W_QNF
                DQV_VT = DQV_CD * CD_VT + DQV_CH * CH_VT&
                        + DQV_CI * CI_VT + DQV_W * W_VT
                DQV_VA = DQV_CD * CD_VA + DQV_CH * CH_VA&
                        + DQV_W * W_VA
                !
                !------ accumulate viscous Power and sensitivities
                QVISR(N) = QVISR(N) + DQV
                QV_OMG(N) = QV_OMG(N) + DQV_OMG
                QV_QNF(N) = QV_QNF(N) + DQV_QNF
                QV_DBE(N) = QV_DBE(N) + DQV_DBE
                !
                QV_GAM(I, N) = DQV_GI
                QV_VA (I, N) = DQV_VA
                QV_VT (I, N) = DQV_VT
                !
            ENDIF ! end of check for IRTYPE=2 (blade defined)
            !
            !
            !*******************************************************
            !------ Inviscid Thrust & Power contributions on rotor
            !
            !------ dTi( Gi , C( Omg Vt ) )
            DTI = -RHO * BGAM(I, N) * CI * DR
            !
            DTI_CI = -RHO * BGAM(I, N) * DR
            DTI_GI = -RHO * CI * DR
            !
            !------ dTi( Adv , Vt(Adw Gj) )
            DTI_VT = DTI_CI * CI_VT
            DTI_OMG = DTI_CI * CI_OMG
            !
            !------ accumulate inviscid Thrust and sensitivities
            TINVR(N) = TINVR(N) + DTI
            TI_OMG(N) = TI_OMG(N) + DTI_OMG
            !------ Resolve dTi dependencies ( Vt ) to Gamma
            TI_GAM(I, N) = DTI_GI
            TI_VA (I, N) = 0.0
            TI_VT (I, N) = DTI_VT
            !
            !
            !------ dQi( S(V Va) , Gi )
            DQI = RHO * BGAM(I, N) * SI * RDR
            !
            DQI_GI = RHO * SI * RDR
            DQI_SI = RHO * BGAM(I, N) * RDR
            !
            !------ dQi( Vai , Qinf, Gi )
            DQI_QNF = DQI_SI * SI_QNF
            DQI_VA = DQI_SI * SI_VA
            !
            !------ accumulate inviscid Power and sensitivities
            QINVR(N) = QINVR(N) + DQI
            QI_OMG(N) = 0.0
            QI_QNF(N) = QI_QNF(N) + DQI_QNF
            !------ Save dQi dependencies to BGAM,VA,VT
            QI_GAM(I, N) = DQI_GI
            QI_VA (I, N) = DQI_VA
            QI_VT (I, N) = 0.0
            !
            !*******************************************************
            !------ Save blade thrust and torque distributions (per blade, per span)
            IF(BLDS.NE.0.0) THEN
                DTII(I, N) = DTI / BDR
                DQII(I, N) = DQI / BDR
                DTVI(I, N) = DTV / BDR
                DQVI(I, N) = DQV / BDR
            ELSE
                !------ or actuator disk thrust and torque distributions (per span)
                DTII(I, N) = DTI / DR
                DQII(I, N) = DQI / DR
                DTVI(I, N) = DTV / DR
                DQVI(I, N) = DQV / DR
            ENDIF
            !------ static pressure rise at this radial station
            DPSI(I, N) = (DTI + DTV) / DA
            !
        1000 CONTINUE
        !
        !---- forces for this rotor
        TTOTR(N) = TINVR(N) + TVISR(N)
        QTOTR(N) = QINVR(N) + QVISR(N)
        !
        !---- total forces (all rotors)
        TTOT = TTOT + TTOTR(N)
        TVIS = TVIS + TVISR(N)
        QTOT = QTOT + QTOTR(N)
        QVIS = QVIS + QVISR(N)
        !
        !---- Derive some power quantities from torque
        PVIS = PVIS + QVISR(N) * OMEGA(N)
        PTOT = PTOT + QTOTR(N) * OMEGA(N)
        !
    2000 CONTINUE
    !
    !      write(*,99) 'TQcalc '
    !      write(*,99) ' Tinv,Ti_qnf,Ti_omg       ',tinv,ti_qnf,ti_omg
    !      write(*,99) ' Tvis,Tv_qnf,Tv_omg,Tv_be ',tvis,tv_qnf,tv_omg,tv_dbe
    !      write(*,99) ' Qinv,Qi_qnf,Qi_omg       ',qinv,qi_qnf,qi_omg
    !      write(*,99) ' Qvis,Qv_qnf,Qv_omg,Pv_be ',qvis,qv_qnf,qv_omg,qv_dbe
    !      write(*,99) ' Pinv,Pvis,Ptot           ',pinv,pvis,ptot
    !
    99   format(A, 4(1x, F12.3))
    !
    RETURN
END
! TQCALC


SUBROUTINE WCALC(N, I, VAIN, VTIN, &
        VTT, &
        VAA, &
        CI, CI_OMG, CI_VT, &
        SI, SI_QNF, SI_VA, &
        W, W_OMG, W_QNF, W_VT, W_VA, &
        PHIB, P_OMG, P_QNF, P_VT, P_VA)
    !
    !---- Calculate velocity components at radial station I on rotor blade
    !
    INCLUDE 'DFDC.inc'
    !
    IF(LBLBL)THEN
        VFAC = BBVFAC(I, N)
    ELSE
        VFAC = 1.0
    ENDIF
    !
    !---- At blade lifting line use averaged circulation for tangential velocity
    VTBG = BGAM(I, N) * PI2I / YRC(I, N)
    VTT = VABS(3, I, N) - 0.5 * VTBG
    VAA = VIND(1, I, N)
    !
    !---- Freestream, body induced and added inflow velocities
    CALL UVINFL(YRC(I, N), VAIN, VTIN)
    !
    CI = -YRC(I, N) * OMEGA(N) + VTIN + VTT
    CI_OMG = -YRC(I, N)
    CI_VT = 1.0
    !
    !      SI     = QINF          + VAIN + VAA         ! v0.70
    SI = (QINF + VAA + VAIN) * VFAC          ! BB entry
    SI_QNF = 1.0
    SI_VA = 1.0
    !
    WSQ = CI * CI + SI * SI
    W = SQRT(WSQ)
    W_OMG = (CI * CI_OMG) / W
    W_QNF = (SI * SI_QNF) / W
    W_VT = (CI * CI_VT) / W
    W_VA = (SI * SI_VA) / W
    !
    PHIB = ATAN2(SI, -CI)
    P_OMG = (SI * CI_OMG) / WSQ
    P_QNF = (-CI * SI_QNF) / WSQ
    P_VT = (SI * CI_VT) / WSQ
    P_VA = (-CI * SI_VA) / WSQ
    !
    IF(LDBG) THEN
        WRITE(LUNDBG, *)  'WCALC @I= ', I
        WRITE(LUNDBG, 99) 'QINF YRC  ', QINF, YRC(I, N)
        WRITE(LUNDBG, 99) 'OMEG      ', OMEGA(N)
        WRITE(LUNDBG, 99) 'VT,VA     ', VTT, VAA
        WRITE(LUNDBG, 99) 'VTIN,VAIN ', VTIN, VAIN
        WRITE(LUNDBG, 99) 'CI,SI,W   ', CI, SI, W
        WRITE(LUNDBG, 99) 'PHI       ', PHIB / DTR
    ENDIF
    !
    99   FORMAT(A, 5(1X, f11.6))
    !
    RETURN
END
! WCALC


SUBROUTINE ROTRPRT(LU)
    INCLUDE 'DFDC.inc'
    DIMENSION W1(IRX)
    CHARACTER SCHAR*1, RTYPE*30
    !---------------------------------------------
    !     Dumps operating state of case to unit LU
    !---------------------------------------------
    !
    WRITE (LU, 1000)
    WRITE(LU, 1001) NAME
    IF(.NOT.LCONV) WRITE(LU, 1002)
    IF(NINFL.GT.0) WRITE(LU, 1005)
    !
    1000 FORMAT(/1X, 76('-'))
    1001 FORMAT(' DFDC  Case:  ', A32)
    1002 FORMAT(/19X, '********** NOT CONVERGED **********', /)
    1003 FORMAT(1X, 76('-'))
    1004 FORMAT(50X)
    1005 FORMAT(' (External slipstream present)')
    !
    !---- dimensional thrust, power, torque, rpm
    TDIM = TTOT + TDUCT
    QDIM = QTOT
    PDIM = PTOT
    TVDIM = TVIS
    PVDIM = PVIS
    TINV = TTOT - TVIS
    QINV = QTOT - QVIS
    PINV = PTOT - PVIS
    !
    !---- Define reference quantities for coefficients
    RREF = RTIP(1)
    AREF = ADISK(1)
    OMEGREF = OMEGA(1)
    !
    !---- standard thrust/power coefficients based on rotational speed
    DREF = 2.0 * RREF
    EN = ABS(OMEGREF * PI2I)
    IF(EN.EQ.0.0) THEN
        CT = 0.0
        CP = 0.0
    ELSE
        CT = TDIM / (RHO * EN**2 * DREF**4)
        CP = PDIM / (RHO * EN**3 * DREF**5)
    ENDIF
    !---- standard thrust/power coefficients based on forward speed
    IF(QINF.GT.0.0) THEN
        TC = TDIM / (0.5 * RHO * QINF**2 * PI * RREF**2)
        PC = PDIM / (0.5 * RHO * QINF**3 * PI * RREF**2)
    ELSE
        TC = 0.0
        PC = 0.0
    ENDIF
    !---- thrust/power coefficients based on tip speed
    !     uses helicopter nomenclature for CT0,CP0,FOM
    VTIP = ABS(OMEGREF * RREF)
    ADV = QINF / VTIP
    IF(VTIP.NE.0.0) THEN
        CT0 = TDIM / (RHO * AREF * VTIP**2)
        CP0 = PDIM / (RHO * AREF * VTIP**3)
    ELSE
        CT0 = 0.0
        CP0 = 0.0
    ENDIF
    IF(CT0.GE.0.0 .AND. CP0.NE.0.0) THEN
        FOM = ABS(CT0)**1.5 / CP0 / 2.0
    ELSE
        FOM = 0.0
    ENDIF
    !
    !---- overall efficiency (all thrust components)
    IF(PDIM.NE.0.0) EFFTOT = QINF * TDIM / PDIM
    !---- induced efficiency (all thrust components)
    IF(PINV.NE.0.0) EFFIND = QINF * (TINV + TDUCT) / PINV
    !---- ideal (actuator disk) efficiency
    IF(TC.EQ.0) THEN
        EIDEAL = 0.0
    ELSE
        TCLIM = MAX(-1.0, TC)
        EIDEAL = 2.0 / (1.0 + SQRT(TCLIM + 1.0))
    ENDIF
    !
    !---- Dump overall case data
    !
    WRITE(LU, 1003)
    IF(IRTYPE(1).EQ.2) THEN
        IF(LBLBL) THEN
            WRITE(LU, 1010)
        ELSE
            WRITE(LU, 1011)
        ENDIF
    ELSE
        WRITE(LU, 1008)
    ENDIF
    !
    WRITE(LU, 1012) QINF, ALTH, DELTAT, &
            RHO, VSO, RMU, &
            TDIM, PDIM, EFFTOT, &
            TVDIM, PVDIM, EFFIND, &
            TDUCT, QDIM, EIDEAL
    !
    WRITE(LU, 1004)
    !
    WRITE(LU, 1014) AREF, RREF, OMEGREF
    !---- Thrust/power coefficients based on rotational speed (propeller syntax)
    WRITE(LU, 1015) CT, CP, ADV * PI
    !---- Thrust/power coefficients based on forward speed (propeller syntax)
    WRITE(LU, 1016) TC, PC, ADV
    !---- Thrust/power coefficients based on tip speed (helicopter nomenclature)
    WRITE(LU, 1017) CT0, CP0, FOM
    !
    1008 FORMAT(' Flow Condition and total Forces')
    1010 FORMAT(' Flow Condition and total Forces', 17X, &
            'Corrected for blade blockage')
    1011 FORMAT(' Flow Condition and total Forces', 17X, &
            'No blade blockage correction')
    1012 FORMAT(/'  Vinf(m/s) :', F10.3, 4X, 'Alt.(km)   :', F9.3, 5X, &
            'DeltaT(dgC):', F9.4, &
            /' rho(kg/m3) :', F11.4, 3X, 'Vsound(m/s):', F9.3, 5X, &
            'mu(kg/m-s) :', E11.4, &
            /' Thrust(N)  :', G11.3, 3X, 'Power(W)   :', G11.3, 3X, &
            'Efficiency :', F9.4, &
            /' Tvisc (N)  :', F11.4, 3X, 'Pvisc(W)   :', G11.3, 3X, &
            'Induced Eff:', F9.4, &
            /' Tduct(N)   :', F11.4, 3X, 'torQue(N-m):', G11.3, 3X, &
            'Ideal Eff  :', F9.4)
    !
    1014 FORMAT('  Area:', F11.5, '  Radius:', F11.5, ' Omega:', F11.5, &
            '  Reference data')
    1015 FORMAT('    Ct:', F11.5, '      Cp:', F11.5, '     J:', F11.5, &
            '  by(Rho,N,Dia)')
    1016 FORMAT('    Tc:', F11.5, '      Pc:', F11.5, '   adv:', F11.5, &
            '  by(Rho,Vinf,Area)  ')
    1017 FORMAT('   CT0:', F11.5, '     CP0:', F11.5, '   FOM:', F11.5, &
            '  by(Rho,R*Omg,Area)')
    !
    !
    !---- Display operating state for each rotor
    !
    DO N = 1, NROTOR
        !
        IADD = 1
        !c      IF(LU.EQ.LUWRIT) IADD = INCR
        !
        WRITE(LU, 1003)
        !
        !---- dimensional thrust, power, torque, rpm
        TDIM = TTOTR(N)
        QDIM = QTOTR(N)
        PDIM = QDIM * OMEGA(N)
        TVDIM = TVISR(N)
        PVDIM = QVISR(N) * OMEGA(N)
        TINV = TINVR(N)
        QINV = QINVR(N)
        PINV = QINV * OMEGA(N)
        !
        !
        !---- Define reference quantities for coefficients
        RREF = RTIP(N)
        AREF = ADISK(N)
        OMEGREF = OMEGA(N)
        RPM = 30.0 * OMEGREF / PI
        !
        !---- standard thrust/power coefficients based on rotational speed
        DIA = 2.0 * RREF
        EN = ABS(OMEGREF * PI2I)
        IF(EN.EQ.0.0) THEN
            CT = 0.0
            CP = 0.0
        ELSE
            CT = TDIM / (RHO * EN**2 * DIA**4)
            CP = PDIM / (RHO * EN**3 * DIA**5)
        ENDIF
        !
        !---- standard thrust/power coefficients based on forward speed
        IF(QINF.GT.0.0) THEN
            TC = TDIM / (0.5 * RHO * QINF**2 * PI * RREF**2)
            PC = PDIM / (0.5 * RHO * QINF**3 * PI * RREF**2)
        ELSE
            TC = 0.0
            PC = 0.0
        ENDIF
        !---- thrust/power coefficients based on tip speed
        !     uses helicopter nomenclature for CT0,CP0,FOM
        VTIP = ABS(OMEGREF * RREF)
        IF(VTIP.NE.0.0) THEN
            CT0 = TDIM / (RHO * AREF * VTIP**2)
            CP0 = PDIM / (RHO * AREF * VTIP**3)
            ADV = QINF / VTIP
        ELSE
            CT0 = 0.0
            CP0 = 0.0
            ADV = 0.0
        ENDIF
        !
        !---- efficiency for rotor
        IF(PDIM.NE.0.0) EFFTOT = QINF * TDIM / PDIM
        !---- induced efficiency for rotor
        IF(PINV.NE.0.0) EFFIND = QINF * TINV / PINV
        !---- ideal (actuator disk) efficiency
        IF(TC.EQ.0) THEN
            EIDEAL = 0.0
        ELSE
            TCLIM = MAX(-1.0, TC)
            EIDEAL = 2.0 / (1.0 + SQRT(TCLIM + 1.0))
        ENDIF
        !
        SIGMA = 0.0
        IF(IRTYPE(N).EQ.1) THEN
            IF(OMEGA(N).EQ.0.0) THEN
                RTYPE = 'Actuator Disk Stator'
            ELSE
                RTYPE = 'Actuator Disk Rotor '
            ENDIF
        ELSEIF(IRTYPE(N).EQ.2) THEN
            IF(OMEGA(N).EQ.0.0) THEN
                RTYPE = 'Bladed Stator '
            ELSE
                RTYPE = 'Bladed Rotor  '
            ENDIF
            !---- Overall blade solidity (measured at 3/4 Rtip)
            CALL SPLINE(CHR(1, N), W1, YRC, NRC)
            CH34 = SEVAL(0.75 * RTIP(N), CHR(1, N), W1, YRC, NRC)
            SIGMA = FLOAT(NRBLD(N)) * CH34 / RTIP(N) / PI
        ELSE
            RTYPE = 'Undefined disk'
        ENDIF
        !
        IF(SIGMA.NE.0.0) THEN
            CTOS = CT0 / SIGMA
        ELSE
            CTOS = 0.0
        ENDIF
        !
        WRITE(LU, 1110) N, RTYPE, &
                NRBLD(N), RPM, ADV, &
                TDIM, PDIM, EFFTOT, &
                TVDIM, PVDIM, EFFIND, &
                QDIM, QINV, EIDEAL, &
                RTIP(N), RHUB(N), VAAVG(N)
        !
        WRITE(LU, 1004)
        WRITE(LU, 1114) AREF, RREF, OMEGREF
        !---- Thrust/power coefficients based on rotational speed (propeller syntax)
        WRITE(LU, 1115) CT, CP, ADV * PI
        !---- Thrust/power coefficients based on forward speed (propeller syntax)
        WRITE(LU, 1116) TC, PC, ADV
        !---- Thrust/power coefficients based on tip speed (helicopter nomenclature)
        WRITE(LU, 1118) CT0, CP0
        WRITE(LU, 1119) SIGMA, CTOS
        !
        WRITE(LU, 1003)
        !
        IF(OMEGA(N).LE.0.0 .AND. IRTYPE(N).EQ.2) THEN
            IF(LCOORD) THEN
                WRITE(LU, *)'                    -local coords-'
            ELSE
                WRITE(LU, *)'                    -global coords-'
            ENDIF
        ENDIF
        !
        !
        IF(IRTYPE(N).EQ.2) THEN
            !---- Blade is defined, print blade data
            !
            !---- Overall blade solidity (measured at 3/4 Rtip)
            CALL SPLINE(CHR(1, N), W1, YRC(1, N), NRC)
            CH34 = SEVAL(0.75 * RTIP(N), CHR(1, N), W1, YRC, NRC)
            SIGMA = FLOAT(NRBLD(N)) * CH34 / RTIP(N) / PI
            IF(SIGMA.NE.0.0) THEN
                CTOS = CT0 / SIGMA
            ELSE
                CTOS = 0.0
            ENDIF
            !
            !----- find maximum RE on blade
            REMAX = 0.0
            DO I = 1, NRC
                REMAX = MAX(RER(I, N), REMAX)
            END DO
            REEXP = 1.0
            IF(REMAX.GE.1.0E6) THEN
                REEXP = 6.0
            ELSEIF(REMAX.GE.1.0E3) THEN
                REEXP = 3.0
            ENDIF
            IF(REEXP.EQ.1.0) THEN
                WRITE(LU, 1120)
            ELSE
                WRITE(LU, 1122) IFIX(REEXP)
            ENDIF
            !
            !---- NOTE: should only dump blade data to NRC-1 for tip gap case
            !
            !       LSTALLR(NRC,N)=.FALSE.
            !
            DO I = 1, NRC, IADD
                XI = YRC(I, N) / RTIP(N)
                CHI = CHR(I, N) / RTIP(N)
                XRE = RER(I, N) / (10.0**REEXP)
                !
                IF(LCOORD .AND. OMEGA(N).LE.0.0) THEN
                    BDEG = (PI - BETAR(I, N)) / DTR
                    ALDEG = -ALFAR(I, N) / DTR
                ELSE
                    BDEG = BETAR(I, N) / DTR
                    ALDEG = ALFAR(I, N) / DTR
                ENDIF
                !
                IF(I.EQ.NRC.AND.TGAP.GT.0.0.AND.OMEGA(N).NE.0.0) ALDEG = 0.0
                !
                SCHAR = ' '
                IF(LSTALLR(I, N)) THEN
                    IF(I.EQ.NRC .AND. TGAP.GT.0.0.AND.OMEGA(N).NE.0.0) THEN
                        SCHAR = ' '
                    ELSE
                        SCHAR = 's'
                    ENDIF
                ENDIF
                !
                WRITE(LU, 1130) I, XI, CHI, BDEG, ALDEG, CLR(I, N), SCHAR, CDR(I, N), &
                        XRE, MACHR(I, N), BGAM(I, N)
                !c     &    EFFI,EFFP(I)
            END DO
            !
        ELSE
            !---- Print actuator disk datal
            WRITE(LU, 1220)
            DO I = 1, NRC, IADD
                XI = YRC(I, N) / RTIP(N)
                WRITE(LU, 1230)&
                        I, XI, MACHR(I, N), BGAM(I, N)
            END DO
        ENDIF
        !
    END DO
    !
    !c      WRITE(LU,1000)
    !c      WRITE(LU,*   ) ' '
    !
    RETURN
    !....................................................................
    !
    1110 FORMAT(1X, 'Disk #', I3, 4X, A, &
            /' # blades   :', I3, 11X, 'RPM        :', F11.3, 3X, &
            'adv. ratio :', F9.4, &
            /' Thrust(N)  :', G11.3, 3X, 'Power(W)   :', G11.3, 3X, &
            'Efficiency :', F9.4, &
            /' Tvisc (N)  :', F11.4, 3X, 'Pvisc(W)   :', G11.3, 3X, &
            'Induced Eff:', F9.4, &
            /' torQue(N-m):', F11.4, 3X, 'Qvisc(N-m) :', G11.3, 3X, &
            'Ideal Eff  :', F9.4, &
            /' radius(m)  :', F9.4, 5X, 'hub rad.(m):', F9.4, 5X, &
            'VAavg (m/s):', F9.4)
    !
    1114 FORMAT('  Area:', F11.5, '  Radius:', F11.5, ' Omega:', F11.5, &
            '  Reference data')
    1115 FORMAT('    Ct:', F11.5, '      Cp:', F11.5, '     J:', F11.5, &
            '  by(Rho,N,Dia)')
    1116 FORMAT('    Tc:', F11.5, '      Pc:', F11.5, '   adv:', F11.5, &
            '  by(Rho,Vinf,Area)  ')
    1118 FORMAT('   CT0:', F11.5, '     CP0:', F11.5, 18X, &
            '  by(Rho,R*Omg,Area)')
    1119 FORMAT(' Sigma:', F11.5, ' CT0/Sig:', F11.5)
    !
    !---- Rotor data
    1120 FORMAT('   i   r/R    c/R     beta deg alfa     CL     CD', &
            '      RE   ', '   Mach    B*Gam')
    1122 FORMAT('   i   r/R    c/R     beta deg alfa     CL     CD', &
            '    REx10^', I1, '   Mach    B*Gam')
    1130 FORMAT(2X, I2, F7.3, F8.4, F8.2, F7.2, 1X, F8.3, A1, F7.4, &
            F8.2, F8.3, F9.3)
    !
    !---- Actuator disk data
    1220 FORMAT('   i   r/R    c/R     beta deg alfa     CL     CD', &
            '      RE   ', '   Mach    B*Gam')
    1230 FORMAT(2X, I2, F7.3, 8X, 8X, 1X, 7X, 1X, 8X, 1X, 7X, &
            7X, F8.3, F9.3)
    !
    !
    ! 1120 FORMAT(/'   i    r/R     c/R    beta(deg)',
    !     & '    CL       Cd     RE        Mach        B*Gam')
    ! 1030 FORMAT(2X,I2,F7.3,8X,8X,8X,2X,1X,F8.4,1X,
    !     &       F7.3,F10.3)
    !   i    r/R     c/R    beta(deg)alfa    CL      Cd      RE     Mach     B*Gam\
    !   i    r/R     c/R    beta(deg)alfa    CL      Cd    REx10^I  Mach     B*Gam')
    !xxiiffffff7fffffff8fffffff8xxxfffffff8xSffffff8xffffff7xxxxffffff7xfffffffff9
    !xx2i f7.3   f8.4    f8.2    3x  f8.3  x   f8.4 x  f7.2 4x    f7.3 x  f10.3
    !
END
! ROTRPRT




SUBROUTINE NFCALC
    !----------------------------------------------------------------
    !     Calculate near-field forces on rotor, momentum, power at disk
    !     Inviscid thrust is calculated from RPM and circulation
    !     This routine is approximate (inviscid only), superseded by
    !     routine TQCALC.
    !----------------------------------------------------------------
    INCLUDE 'DFDC.inc'
    !
    DO N = 1, NROTOR
        !
        !---- Calculate rotor inviscid thrust from circulation
        OMEG = OMEGA(N)
        THRUST = 0.0
        DO IR = 1, NRC
            DR = YRP(IR + 1, N) - YRP(IR, N)
            DA = PI * (YRP(IR + 1, N)**2 - YRP(IR, N)**2)
            !---- use theta velocity at blade (1/2 of induced Vt in slipstream)
            VTB = 0.5 * BGAM(IR, N) * PI2I / YRC(IR, N)
            WTB = VTB - OMEG * YRC(IR, N)
            DTHR = DR * RHO * (-WTB) * BGAM(IR, N)
            THRUST = THRUST + DTHR
        END DO
        WRITE(*, *) 'Thrust from rotor GAM and OMEGA', THRUST
        IF(LDBG) THEN
            WRITE(LUNDBG, *) 'Thrust from rotor GAM and OMEGA', THRUST
        ENDIF
        !
        !---- Near-field thrust from momentum theory using rotor velocities
        AREA = 0.0
        THRUSTM = 0.0
        POWERM = 0.0
        POWERMT = 0.0
        DO IR = 1, NRC
            DR = YRP(IR + 1, N) - YRP(IR, N)
            DA = PI * (YRP(IR + 1, N)**2 - YRP(IR, N)**2)
            !
            US = VABS(1, IR, N)
            VS = VABS(2, IR, N)
            WS = VABS(3, IR, N)
            VSQ = US * US + VS * VS + WS * WS
            DT = DA * RHO * US * (US - QINF)
            DP = DA * RHO * US * (0.5 * VSQ - 0.5 * QINF * QINF)
            DPT = DA * RHO * US * (0.5 * WS**2)
            !
            AREA = AREA + DA
            THRUSTM = THRUSTM + DT
            POWERM = POWERM + DP
            POWERMT = POWERMT + DPT
            !
        END DO
        !
        WRITE(*, *) 'Momentum integration in near-field for rotor # ', N
        WRITE(*, *) '       Area   = ', AREA
        WRITE(*, *) '   mom.Thrust = ', THRUSTM
        WRITE(*, *) '   mom.Power  = ', POWERM
        WRITE(*, *) ' swirl Power  = ', POWERMT
        !
    END DO
    !
    RETURN
END
! NFCALC




SUBROUTINE FFCALC
    INCLUDE 'DFDC.inc'
    !---------------------------------------------------------
    !     Integrates forces (thrust and power at FF boundary)
    !---------------------------------------------------------
    !
    TINT = 0.0
    TINTH = 0.0
    PINT = 0.0
    PINTH = 0.0
    PINTT = 0.0
    !
    DO IR = 1, NRP - 1
        !
        FMR = RHO * VABS(1, IR, 1) * PI * (YRP(IR + 1, 1)**2 - YRP(IR, 1)**2)
        !
        IELO = IR2IEL(IR)
        IELP = IR2IEL(IR + 1)
        IPO = IPLAST(IELO)
        IPP = IPLAST(IELP)
        XFF = 0.5 * (XP(IPO) + XP(IPP)) - 0.5 * (XP(IPP) - XP(IPP - 1))
        YFF = 0.5 * (YP(IPO) + YP(IPP))
        DY = YP(IPP) - YP(IPO)
        !
        CALL GETUV(XFF, YFF, US, VS)
        WS = BGAMG(II - 1, IR) * PI2I / YFF
        VSQ = US * US + VS * VS + WS * WS
        !
        DA = 2.0 * PI * YFF * DY
        FM = DA * RHO * US
        DT = DA * RHO * US * (US - QINF)
        DP = DA * RHO * US * (0.5 * VSQ - 0.5 * QINF * QINF)
        DPT = DA * RHO * US * (0.5 * WS**2)
        !
        AREA = AREA + DA
        TINT = TINT + DT
        PINT = PINT + DP
        PINTT = PINTT + DPT
        !
        WRITE(*, *) 'IR,FM,FMR ', IR, FM, FMR
        !
        !---- Use enthalpy, entropy and circulation at far-field
        USQ = QINF * QINF - WS * WS + 2.0 * (DHG(II - 1, IR) - DSG(II - 1, IR))
        US = SQRT(USQ)
        VSQ = US * US + WS * WS
        DT = FMR * (US - QINF)
        DP = FMR * (0.5 * VSQ - 0.5 * QINF * QINF)
        TINTH = TINTH + DT
        PINTH = PINTH + DP
        !
    END DO
    !
    WRITE(*, *) 'FFCALC Area   = ', AREA
    WRITE(*, *) '       Thrust = ', TINT
    WRITE(*, *) '       Power  = ', PINT
    WRITE(*, *) ' Swirl Power  = ', PINTT
    WRITE(*, *) '   FF  Thrust = ', TINTH
    WRITE(*, *) '   FF  Power  = ', PINTH
    !
    RETURN
END


SUBROUTINE STGFIND
    INCLUDE 'DFDC.inc'
    !---------------------------------------------------------
    !     Find stagnation points on CB and duct
    !     The panel center index and X,Y location are saved
    !---------------------------------------------------------
    !
    !---- Stagnation point on axisymmetric CB is simply the upstream point
    IEL = 1
    IC1 = ICFRST(IEL)
    IC2 = ICLAST(IEL)
    IP1 = IPFRST(IEL)
    IP2 = IPLAST(IEL)
    ICSTG(IEL) = IC2
    XSTG(IEL) = XP(IP2)
    YSTG(IEL) = YP(IP2)
    !
    !---- Stagnation point on duct must be found by search in tangential velocity
    IEL = 2
    IC1 = ICFRST(IEL)
    IC2 = ICLAST(IEL)
    IP1 = IPFRST(IEL)
    IP2 = IPLAST(IEL)
    !
    ICSTG(IEL) = IC1
    XSTG(IEL) = XP(IP1)
    YSTG(IEL) = YP(IP1)
    !
    DO IC = IC1, IC2
        QD = -ANC(2, IC) * QCR(1, IC) + ANC(1, IC) * QCR(2, IC)
        !c        write(*,*) 'ic,qd ',ic,qd
        IF(IC.GT.IC1) THEN
            IF(QD * QDOLD.LT.0.0) THEN
                !c            WRITE(*,*) 'Found stagnation point at IC=',IC
                !c            WRITE(*,*) ' QD, QDOLD ',QD,QDOLD
                !c            write(*,*) 'xc,yc ',XC(IC),YC(IC)
                !
                D1 = 0.5 * DSC(IC - 1)
                D2 = 0.5 * DSC(IC)
                D12 = D1 + D2
                DFRAC = D1 / D12
                QFRAC = QD / (QD - QDOLD)
                !c            write(*,*) 'd1,d2,dfrac ',d1,d2,dfrac
                !c            write(*,*) 'qfrac ',qfrac
                IF(QFRAC.LT.DFRAC) THEN
                    ICSTG(IEL) = IC - 1
                    XSTG(IEL) = XC(IC - 1) + (1.0 - QFRAC) * D12 * (-ANC(2, IC - 1))
                    YSTG(IEL) = YC(IC - 1) + (1.0 - QFRAC) * D12 * (ANC(1, IC - 1))
                ELSE
                    ICSTG(IEL) = IC
                    XSTG(IEL) = XC(IC) - (QFRAC) * D12 * (-ANC(2, IC))
                    YSTG(IEL) = YC(IC) - (QFRAC) * D12 * (ANC(1, IC))
                ENDIF
                GO TO 10
            ENDIF
        ENDIF
        QDOLD = QD
    END DO
    !
    10   IF(LDBG) THEN
        IEL = 1
        WRITE(*, *) 'Element 1 Stag @ IC,X,Y ', &
                ICSTG(IEL), XSTG(IEL), YSTG(IEL)
        IEL = 2
        WRITE(*, *) 'Element 2 Stag @ IC,X,Y ', &
                ICSTG(IEL), XSTG(IEL), YSTG(IEL)
    ENDIF
    !
    RETURN
END

