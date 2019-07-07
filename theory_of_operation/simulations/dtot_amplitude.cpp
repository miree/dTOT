#include <iostream>
#include <sstream>
#include <cmath>

double L(double t, double tau_SCI)
{
	return exp(-t/tau_SCI)/tau_SCI;
}

// log1mexp(a) := log(1-exp(-a)), a > 0
double log1mexp(double a) {
	if (a < 0.693) return log(-expm1(-a)); // log( -(exp(-a)-1)) 
	else           return log1p(-exp(-a)); // log( 1 + -exp(-a)) 
}

// logexpm1(a) := log(exp(a)-1), a > 0
double logexpm1(double a) {
	if (a < 37)  return log(expm1(a));
	else         return a;

}

double log_q_analytic(double t, double tau, double RC) 
{
	if (tau == RC) {
		return log(t/tau) - t/tau;
	}
	if (RC > tau) {
		return log(RC/(RC-tau)) + log1mexp(t*(RC-tau)/RC/tau) - t/RC;
	}
	else {
		return log(RC/(tau-RC)) + logexpm1(t*(tau-RC)/RC/tau) -t/RC;
	}
}

double q_analytic(double t, double tau, double RC)
{
	if (tau == RC) {
		return t/tau*exp(-t/tau);
	}

	return RC/(tau-RC)*(exp(t/tau*(tau-RC)/RC)-1)*exp(-t/RC);
}

double diff_q_analytic(double t, double tau, double RC)
{
	if (tau == RC) {
		return ((tau-t)*exp(-t/tau))/tau/tau;
	}

	return exp((t*(tau-RC))/(RC*tau)-t/RC)/tau-(exp(-t/RC) *(exp(t*(tau-RC)/(RC*tau))-1))/(tau-RC);
}

double diff2_q_analytic(double t, double tau, double RC) 
{
	if (tau == RC) {
		return -((2*tau-t)*exp(-t/tau))/tau/tau/tau;
	}
	return -(exp(-t/tau)*(tau*tau*exp(t/tau)-RC*RC*exp(t/RC)))/(RC*exp(t/RC)*tau*tau*tau-RC*RC*exp(t/RC)*tau*tau);
}

double q_tmax(double tau, double RC)
{
	// find zero of first derivative using Newton method
	double tmax = 0;
	for(;;)
	{
		double height = diff_q_analytic(tmax,tau,RC);
		double slope  = diff2_q_analytic(tmax,tau,RC);
		double dtmax  = -height/slope;
		tmax += dtmax;
		if (dtmax < 1e-9) {
			return tmax;
		}
	}
}

double t_leading_edge(double tau, double RC, double threshold)
{
	double tmin = 0;
	double tmax = q_tmax(tau, RC);

	// is it even possible to find a solution?
	if (log_q_analytic(tmax, tau, RC) < log(threshold)) {
		return -1; // no
	}

	for (;;) 
	{
		//std::cout << tmin << " < " << tmax << std::endl;
		double tmed = 0.5*(tmin+tmax);
		if (tmax-tmin < 1e-9) {
			return tmed;
		}
		double log_qmed = log_q_analytic(tmed,tau,RC);
		if (log_qmed > log(threshold)) {
			tmax = tmed;
		} else {
			tmin = tmed;
		}
	}
}

double dynamic_threshold(double t, double t0, double threshold_low, double threshold_high, double tau_threshold)
{
	if (t < t0) {
		return threshold_low;
	}
	return threshold_low + (1-exp(-(t-t0)/tau_threshold))*(threshold_high-threshold_low);
}
double dtot(double tau, double RC, double threshold_low, double threshold_high, double tau_threshold, double trigger_delay)
{
	double t_leading = t_leading_edge(tau, RC, threshold_low)+trigger_delay;
	if (t_leading < 0) {
		return 0;
	}
	//double q_laeding = q_analytic(t_leading, tau, RC);

	double tmax = q_tmax(tau, RC);

	// find a point after crossing
	double t_trailing_max = t_leading;
	for (;;) 
	{
		t_trailing_max += tau+RC;
		if (log_q_analytic(t_trailing_max,tau,RC) <
		       log(dynamic_threshold(t_trailing_max, t_leading, 
		       	                 threshold_low, threshold_high, tau_threshold))) {
			break;
		}
	}
	//std::cerr << t_leading << " " << t_trailing << std::endl;

	// crossing point is somewhere between t_leading and t_trailing
	double t_trailing_min = t_leading;
	for (;;)
	{
		double t_med = 0.5*(t_trailing_min+t_trailing_max);
		//std::cout << t_med << std::endl;
		if (t_trailing_max-t_trailing_min < 1e-9) {
			return t_med-t_leading+trigger_delay;
		}
		if (log_q_analytic(t_med,tau,RC) <
		       log(dynamic_threshold(t_med, t_leading, 
		       	                 threshold_low, threshold_high, tau_threshold))) {
			t_trailing_max = t_med;
		} else {
			t_trailing_min = t_med;
		}
	}
}


int main(int argc, char *argv[])
{

	if (argc != 7) {
		std::cerr << "usage: " << argv[0] << " tau RC threshold_min threshold_tau trigger_delay Amax" << std::endl;
		return 1;
	}

	std::istringstream tau_in(argv[1]);
	double tau;
	tau_in >> tau;

	std::istringstream RC_in(argv[2]);
	double RC;
	RC_in >> RC;
	
	std::istringstream threshold_min_in(argv[3]);
	double threshold_min;
	threshold_min_in >> threshold_min;

	std::istringstream threshold_tau_in(argv[4]);
	double threshold_tau;
	threshold_tau_in >> threshold_tau;

	std::istringstream trig_delay_in(argv[5]);
	double trig_delay;
	trig_delay_in >> trig_delay;

	std::istringstream Amax_in(argv[6]);
	double Amax;
	Amax_in >> Amax;

	double tmax = q_tmax(tau,RC);
	double qmax = q_analytic(tmax,tau,RC);

	int N = 1000;
	double relative_ampl_min =     0; // amplitude relative to high threshold
	double relative_ampl_max =  Amax;
	for (int i = 1; i <= N; ++i)
	{
		double rel_amplitude = relative_ampl_min + i*(relative_ampl_max-relative_ampl_min)/N;

		double th_high = qmax / rel_amplitude; 
		double th_low  = th_high*threshold_min;

		//std::cerr << th_low << " " << th_high << std::endl;

		std::cout << rel_amplitude << " " << dtot(tau,RC,th_low,th_high,threshold_tau,trig_delay) << std::endl;

	}

	return 0;
}
