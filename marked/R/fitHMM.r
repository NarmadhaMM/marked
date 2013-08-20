#' Hidden Markov Model fitting
#' 
#' A rudimentary fitting function that sets up values for HMMLikelihood and loglikelihood and
#' calls optim to find mininmum of loglikelihood for a set of parameters.
#'  
#' @param data Either the raw data which is a dataframe with at least one
#' column named ch (a character field containing the capture history) or a
#' processed dataframe
#' @param ddl Design data list which contains a list element for each parameter
#' type; if NULL it is created
#' @param begin.time Time of first capture(release) occasion
#' @param model Type of c-r model (eg "cjs" "js")
#' @param title Optional title; not used at present
#' @param design.parameters Specification of any grouping variables for design
#' data for each parameter
#' @param model.parameters List of model parameter specifications
#' @param initial Optional list (by parameter type) of initial values for beta parameters (e.g., initial=list(Phi=0.3,p=-2)
#' @param groups Vector of names of factor variables for creating groups
#' @param time.intervals Intervals of time between the capture occasions
#' @param method optimization method for function \code{optimx}
#' @param debug if TRUE, shows optimization output
#' @param hessian if TRUE, computes v-c matrix using hessian
#' @param accumulate if TRUE, like capture-histories are accumulated to reduce
#' computation
#' @param control control string for optimization functions
#' @param itnmax maximum number of iterations for optimization 
#' @param run if TRUE, it runs model; otherwise if FALSE can be used to test model and return build components 
#' @param strata.labels labels for strata used in capture history; they are converted to numeric in the order listed. Only needed to specify unobserved strata. For any unobserved strata p=0..
#' @return result from optim
#' @author Jeff Laake <jeff.laake@@noaa.gov>
#' @export
#' @references Zucchini, W. and I.L. MacDonald. 2009. Hidden Markov Models for Time Series: An Introduction using R. Chapman and Hall, Boca Raton, FL. 275p.
fitHMM=function(data,ddl=NULL,begin.time=1,model="hmmCJS",title="",model.parameters=list(),design.parameters=list(),initial=NULL,
		groups = NULL, time.intervals = NULL,debug=FALSE, method="BFGS", hessian=FALSE, accumulate=TRUE,control=NULL,itnmax=5000,
		run=TRUE,strata.labels=NULL)
{
#
#  If the data haven't been processed (data$data is NULL) do it now with specified or default arguments
# 
	if(is.null(data$data))
	{
		if(!is.null(ddl))
		{
			warning("Warning: specification of ddl ignored, as data have not been processed")
			ddl=NULL
		}
		cat("Model: ",model,"\n")
		cat("Processing data\n")
		flush.console()
		data.proc=process.data(data,begin.time=begin.time, model=model,mixtures=1, 
				groups = groups, age.var = NULL, initial.ages = NULL, 
				time.intervals = time.intervals,nocc=NULL,accumulate=accumulate,strata.labels=strata.labels)
	}   
	else
	{
		data.proc=data
		model=data$model
	}
	if(substr(model,1,3)!="hmm") stop("\n ",model," is not an HMM model \n")
#
# If the design data have not been constructed, do so now
#
	if(is.null(ddl)) 
	{
		cat("Creating design data. This can take awhile.\n")
		flush.console()
		ddl=make.design.data(data.proc,design.parameters)
	} else
		design.parameters=ddl$design.parameters
    #
    # setup parameter list
    #
	number.of.groups=1
	if(!is.null(data.proc$group.covariates))number.of.groups=nrow(data.proc$group.covariates)
	par.list=setup.parameters(data.proc$model,check=TRUE)
	#
	# check validity of parameter list; stop if not valid
	#
	if(!valid.parameters(model,model.parameters)) stop()
	parameters=setup.parameters(data.proc$model,model.parameters,data$nocc,number.of.groups=number.of.groups)
	parameters=parameters[par.list]
	for (i in 1:length(parameters))
		if(is.null(parameters[[i]]$formula)) parameters[[i]]$formula=~1
	#
	#  get parameter partition to split vector to list and setup initial values
    #
	ptype=NULL
	par=NULL
	total.npar=0
	beta.labels=list()
	for(parname in names(parameters))
	{
		beta.labels[[parname]]=reals(parname,ddl=ddl[[parname]],parameters=parameters,compute=FALSE)
		npar=length(beta.labels[[parname]])
		total.npar=total.npar+npar
		ptype=c(ptype,rep(parname,npar))	
		if(!is.null(initial))
		{
			if(!is.null(initial[[parname]]))
			{
				if(length(initial[[parname]])==npar)
					par=c(par,initial[[parname]])
			    else
				{
					warning("Incorrect number of initial values for ",parname," need", npar, " Setting all to 0.\n")
					par=c(par,rep(0,npar))
				}
			} else
				par=c(par,rep(0,npar))
		}
			
	}
	if(is.null(initial))
		par=rep(0,total.npar)
	# start - for each ch, the first non-zero x value and the occasion of the first non-zero value
	#start=t(sapply(data.proc$data$ch,function(x){
	#					xx=strsplit(x,",")[[1]]
	#					ich=min(which(strsplit(x,",")[[1]]!="0"))
	#					return(c(as.numeric(factor(xx[ich],levels=data.proc$ObsLevels))-1,ich))
	#				}))
	# create encounter history matrix
	#x=t(sapply(strsplit(data.proc$data$ch,","),function(x) as.numeric(factor(x,levels=data.proc$ObsLevels))))
	
	if(run)
	{
		fit=optim(par,loglikelihood,type=ptype,x=data.proc$ehmat,m=data.proc$m,T=data.proc$nocc,start=data.proc$start,freq=data.proc$freq,
				fct_dmat=data.proc$fct_dmat,fct_gamma=data.proc$fct_gamma,fct_delta=data.proc$fct_delta,ddl=ddl,parameters=parameters,control=control,
				method=method,debug=debug,hessian=hessian)
		par=split(fit$par,ptype)
		for(p in names(par))
		{
		    if(is.null(model.parameters[[p]]$formula))
				names(par[[p]])="(Intercept)"
            else
			    names(par[[p]])=beta.labels[[p]]
		}
		return(list(data=data.proc,ddl=ddl,par=par,model.parameters=parameters,fit=fit))
	}
    else
		return(list(data=data.proc,ddl=ddl,ptype=ptype,start=data.proc$start,x=data.proc$ehmat,par=par,model.parameters=parameters))
}
