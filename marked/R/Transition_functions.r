#' HMM Transition matrix functions
#' 
#' Functions that compute the transition matrix for various models. Currently only CJS and MS models
#' are included.
#'  
#' @param pars list of real parameter values for each type of parameter
#' @param m number of states
#' @param T number of occasions
#' @aliases cjs_gamma ms_gamma
#' @return array of id and occasion-specific transition matrices - Gamma in Zucchini and MacDonald (2009)
#' @author Jeff Laake <jeff.laake@@noaa.gov>
#' @references Zucchini, W. and I.L. MacDonald. 2009. Hidden Markov Models for Time Series: An Introduction using R. Chapman and Hall, Boca Raton, FL. 275p. 
cjs_gamma=function(pars,m,T) 
{
	# create 4-d array with a matrix for each id and occasion
	# from pars$Phi which is a matrix of id by occasion survival probabilities 	
	aaply(pars$Phi,c(1,2),function(phi) {
				matrix(c(phi,1-phi,0,1),nrow=2,ncol=2,byrow=TRUE)})
}
ms_gamma=function(pars,m,T) 
{
	# create an 4-d array with a matrix for each id and occasion for S from pars$S 
	# which is a matrix of id by occasion x state survival probabilities
	phimat=aaply(pars$S,1,function(x) 
			{
				laply(split(x,rep(1:(T-1),each=m-1)),function(s) 
						{
							phimat=matrix(s,ncol=length(s),nrow=length(s))
							rbind(cbind(phimat,1-s),c(rep(0,length(s)),1))
						})
			})
	# create a 4-d array from pars$Psi which is a matrix of id by occasion x state^2 
	# non-normalized Psi probabilities which are normalized to sum to 1. 			
	psimat=aaply(pars$Psi,1,function(x) 
			{
				laply(split(x,rep(1:(T-1),each=(m-1)*(m-1))),function(psi) 
						{
							psimat=matrix(psi,ncol=sqrt(length(psi)),byrow=TRUE)
							psimat=psimat/rowSums(psimat)
							rbind(cbind(psimat,rep(1,nrow(psimat))),rep(1,nrow(psimat)+1))
						})
			})
	# The 4-d arrays are multiplied and returned
	phimat*psimat
}
