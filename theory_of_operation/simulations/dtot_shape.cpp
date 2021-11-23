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

double dynamic_threshold_full(double t, double t0, double t1, double threshold_low, double threshold_high, double tau_threshold)
{
	if (t < t0) {
		return threshold_low;
	} 
	if (t < t1) {
		return threshold_low + (1-exp(-(t-t0)/tau_threshold))*(threshold_high-threshold_low);
	}
	double h_trailing = threshold_low + (1-exp(-(t1-t0)/tau_threshold))*(threshold_high-threshold_low);
	return threshold_low + exp(-(t-t1)/tau_threshold)*(h_trailing-threshold_low);
}

double dynamic_threshold(double t, double t0, double threshold_low, double threshold_high, double tau_threshold)
{
	if (t < t0) {
		return threshold_low;
	}
	return threshold_low + (1-exp(-(t-t0)/tau_threshold))*(threshold_high-threshold_low);
}
double t_trailing_edge(double tau, double RC, double threshold_low, double threshold_high, double tau_threshold, double trigger_delay_leading, double trigger_delay_trailing)
{
	double t_leading = t_leading_edge(tau, RC, threshold_low)+trigger_delay_leading;
	double q_laeding = q_analytic(t_leading, tau, RC);

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
			return t_med+trigger_delay_trailing;
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

	if (argc != 8) {
		std::cerr << "usage: " << argv[0] << " tau RC THmin/THmax amplitude/THmax THtau trig_delay_leading trig_delay_trailing" << std::endl;
		return 1;
	}

	std::istringstream tau_in(argv[1]);
	double tau;
	tau_in >> tau;

	std::istringstream RC_in(argv[2]);
	double RC;
	RC_in >> RC;
	
	std::istringstream THmin_THmax_in(argv[3]);
	double THmin_THmax;
	THmin_THmax_in >> THmin_THmax;

	std::istringstream amplitude_THmax_in(argv[4]);
	double amplitude_THmax;
	amplitude_THmax_in >> amplitude_THmax;
	double THmax = 1.0/amplitude_THmax;
	double THmin = THmin_THmax*THmax;

	std::istringstream THtau_in(argv[5]);
	double THtau;
	THtau_in >> THtau;

	std::istringstream trig_delay_leading_in(argv[6]);
	double trig_delay_leading;
	trig_delay_leading_in >> trig_delay_leading;

	std::istringstream trig_delay_trailing_in(argv[7]);
	double trig_delay_trailing;
	trig_delay_trailing_in >> trig_delay_trailing;

	double tmax = q_tmax(tau,RC);
	double qmax = q_analytic(tmax,tau,RC);
	THmin *= qmax;
	THmax *= qmax;
	std::cerr << "THmin = " << THmin << std::endl;
	std::cerr << "THmax = " << THmax << std::endl;

	double t_leading=t_leading_edge(tau,RC,THmin);
	if (t_leading<0) {
		std::cerr << "no solution, THmin must be smaller than amplitude" << std::endl;
		return -1;
	}
	t_leading+=trig_delay_leading;
	double t_trailing=t_trailing_edge(tau,RC,THmin,THmax,THtau,trig_delay_leading, trig_delay_trailing);

	std::cerr << "#tmax                = " << tmax << std::endl;
	std::cerr << "#qmax                = " << qmax << std::endl;
	std::cerr << "#t_leading           = " << t_leading << std::endl;
	std::cerr << "#q_tleading          = " << q_analytic(t_leading,tau,RC) << std::endl;
	std::cerr << "#t_trailing          = " << t_trailing << std::endl;
	std::cerr << "#q_trailing          = " << q_analytic(t_trailing,tau,RC) << std::endl;
	std::cerr << "#trig_delay_leading  = " << trig_delay_leading << std::endl;
	std::cerr << "#trig_delay_trailing = " << trig_delay_trailing << std::endl;
	std::cerr << "DTOT                 = " << t_trailing-t_leading << std::endl;

	int N = 1000;
	for (int i = 0; i < N/10; ++i) {
		double t = 3.0*(i-N/10)*t_trailing/N;
		std::cout << t << " " << 0 << " " << THmin << std::endl;
	}	
	for (int i = 0; i < N; ++i) {
		double t = 6.0*i*t_trailing/N;
		std::cout << t << " " 
		          << q_analytic(t,tau,RC) << " " 
		          << dynamic_threshold_full(t,t_leading, t_trailing, THmin, THmax, THtau) << " "
		          << std::endl;
	}

	return 0;
}
