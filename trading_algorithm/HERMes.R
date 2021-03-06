#												#
#												#
#	Alessandro Solbiati - HERMes - August 2016	#
#												#
#												#


#EWMA_RiskMetrics()®

calc_VaRnorm<- function(Serie,conf,VaR,s_startdate,s_enddate){

  

  require(timeSeries)

  

  cc<- -(Serie) 

  cc<- window(cc,start=s_startdate,end=s_enddate)

  cc<- as.vector(cc)

  

  me<- mean(cc) #mean

  ds<- sd(cc)	#standard deviation

  

  if (VaR) { out<- me+ds*qnorm(conf) } #compute VaR as a normal distr

  else { out<- me+ds*dnorm(qnorm(conf))/(1-conf) } #compute ES

 

  out

}
calc_VaRnp<- function(Serie,conf,VaR,s_startdate,s_enddate){

  

  require(timeSeries)

  

  cc<- -(Serie) 

  cc<- window(cc,start=s_startdate,end=s_enddate)

  cc<- sort(as.vector(cc))

  out<- cc[ceiling(conf*length(cc))] #NP VaR

  if (!VaR) { out<- mean(cc[cc>out]) }  #NP ES

  

  out

}
funzDens<- function(x,me,ds,nu){

  out<- 1/ds*dt((x-me)/ds,nu)

  out

}
calc_VaRt <- function(Serie,conf,VaR,s_startdate,s_enddate,init=c(0,1,1)){

  

  require(timeSeries)

  require(MASS)

  

  cc<- -(Serie) 

  cc<- window(cc,start=s_startdate,end=s_enddate)

  cc<- as.vector(cc)

  

  #through a likelihood function we estimate distribution parameters

  ss<- fitdistr(cc,funzDens,start=list(me=init[1],ds=init[2],nu=init[3]))

  

  if (VaR) { 

  	#computing VaR 

    out<- ss$estimate[1]+ss$estimate[2]*qt(conf,ss$estimate[3])

  }

  

  else {

  	#computing ES 

  	if (ss$estimate[3]>1) {

    	depo<- dt(qt(conf,ss$estimate[3]),ss$estimate[3])/(1-conf)

    	depo<- depo*(ss$estimate[3]+(qt(conf,ss$estimate[3]))^2)/(ss$estimate[3]-1)

    	}

  	else { depo<- NA }

    out<- ss$estimate[1]+ss$estimate[2]*depo

  }

  

  as.numeric(out)

  

}
calc_Volatility <- function(X_t, N){

  

  require(timeSeries)

  sigma_t <- c()

  is.timeSeries(sigma_t)

  w<- 0.94^(0:74) #lambda = 0.94, T=77 as specified in RiskMetrics

  sigma_t[77]<- sum(w*X_t[76:2]^2)/sum(w) #compute the 77th term 

  for (s in 78:N){ #and all the others

    sigma_t[s]<- 0.94*sigma_t[s-1]+0.06*X_t[s-1]^2

  }

  sigma_t<- sqrt(sigma_t) #here it is the conditioned volatility serie

  sigma_t 

  

  

  }
exe_backtesting <- function(X_t,VaR,Ns,Nt,conf){

	

  w<- sum(X_t[(Ns+1):Nt]<(-VaR[(Ns+1):Nt])) #compute the number of excpetions

  ttest<- binom.test(w,Nt-Ns,1-conf,'t') #execute a binomial test on the numbers of exceptions

 

  #could be implemented other statistical tests, like a approximated normal distribution test

 

  ttest

}

EWMA_RiskMetrics<- function(Serie,conf,usage,s_startdate,s_enddate,VaR,Nt = length(Serie)){

  
  print("starting EWMA_RiskMetrics()®")
  require(timeSeries)

  

  print("calculating returns of the prices and put it in a vector SSt")
  SSt<- cbind(Price_t=Serie,X_t=c(NA,returns(Serie)),sigma_t=NA,VaR=NA)

  
  print("length of the statistical sample")
  Ns<- length(window(SSt[,2],start=s_startdate,end=s_enddate)) 
  print(Ns)

  

  print("Computing the conditioned volatility with the EWMA formula")

  SSt$sigma_t=calc_Volatility(SSt$X_t,Nt)

  

  print("Computing standardized residuals") 

  Z_t<- as.timeSeries(SSt$X_t[77:Ns]/SSt$sigma_t[77:Ns])

  rownames(Z_t)<- rownames(SSt)[77:Ns] 

  

  print("computing VaR_Z estimations")




  if (usage==1) { VaR_Z<- calc_VaRnp(-Z_t,conf,VaR,s_startdate=s_startdate,s_enddate=s_enddate) }

  if (usage==2) { VaR_Z<- calc_VaRnorm(-Z_t,conf,VaR,s_startdate=s_startdate,s_enddate=s_enddate) }

  if (usage==3) { VaR_Z<- calc_VaRt(-Z_t,conf,VaR,s_startdate=s_startdate,s_enddate=s_enddate) }

  #in the 3rd VaR_Z method (student's t) there could be a convergence error due to the initial value of the computing algorithm, 

  #to fix this issue just need to add the argument "init=c(a,b,c)" where a, b and c are three numbers you can aribtrarily choose

  print(VaR_Z)

  

  print("Compute conditioned VaR serie")

  

  SSt$VaR<- SSt$sigma_t*VaR_Z

  




  print("backtesting")

  test <- exe_backtesting(X_t = SSt$X_t, VaR = SSt$VaR, Ns=Ns, Nt=Nt, conf=conf)

  

  print("output pvalue")
  

  EWMA_result <- cbind(SSt,test$p.value,test$estimate)

  EWMA_result
  
  
  

  #to get the test$p.value use the command "as.numeric(EWMA_RiskMetrics(...)[1,5])"

  

}

getprice <- function(name_code){

	

	require(tseries)

	require(timeSeries)

		

	

	pp <- get.hist.quote(instrument=name_code,quote="Close")

	pp <- as.timeSeries(pp)

	pp

	




}
pvs_mat <- function(serie,start,end){


	print("starting to compute p_values matrix")

	pvs <- matrix(nrow=3,ncol=4)

	rownames(pvs) <- c("Non-Parametric","Normal Distr","Student T Distr")

	colnames(pvs) <- c("conf 0.90","conf 0.95","conf 0.99","conf 0.995")




	conf <- 0.9

	j <- 1

	for(i in 1:3){

		pvs[i,j]=as.numeric(EWMA_RiskMetrics(serie,conf,i,start,end,VaR=TRUE)[1,5])

		}




	conf <- 0.95

	j <- 2

	for(i in 1:3){

		pvs[i,j]=as.numeric(EWMA_RiskMetrics(serie,conf,i,start,end,VaR=TRUE)[1,5])

		}

		

	conf <- 0.99

	j <- 3

	for(i in 1:3){

		pvs[i,j]=as.numeric(EWMA_RiskMetrics(serie,conf,i,start,end,VaR=TRUE)[1,5])

		}




	conf <- 0.995

	j <- 4

	for(i in 1:3){

		pvs[i,j]=as.numeric(EWMA_RiskMetrics(serie,conf,i,start,end,VaR=TRUE)[1,5])

	}

	

	pvs

	}
max_pv <- function(serie,start,end){

	

	my_mat <- pvs_mat(serie,start,end)

	

	pv <- 0

	row <- 0

	col <- 0

	for(i in 1:3){

		for(j in 1:4){

			if(my_mat[i,j]>pv){

				pv <- my_mat[i,j]

				row=i

				col=j

			}

		}

	}

	

	out <- c(pv,row,col)

	out

	

}
study <- function(serie,start,end,N_day){

	print("start VaR EF study")
	
	print("getting max p-value")
	vect <- max_pv(serie,start,end)

	usage <- vect[2]

	col <- vect[3]

	

	if(col==1){conf <- 0.9}

	if(col==2){conf <- 0.95}

	if(col==3){conf <- 0.99}

	if(col==4){conf <- 0.995}

	
	print("calc VaR and ES with best conf/usage")
	ewma_VaR <- EWMA_RiskMetrics(serie, conf, usage, start, end, VaR=TRUE, Nt=N_day)

	ewma_ES <- EWMA_RiskMetrics(serie, conf, usage, start, end, VaR=FALSE, Nt=N_day)

	l=length(ewma_VaR[,1])

	
	print("concluding study")
	out <- cbind("Value at Risk"=ewma_VaR[,4],"Expected Shortfall"=ewma_ES[,4],"p-value"=ewma_VaR[l,5])

	out <- cbind(out,"confidence"=conf)

	out

	

}
display_study <- function(titles, start, end){




	studies_var <- c()

	for(i in 1:length(titles)){

		sst <- getprice(titles[i])

		studies_var[i]=study(sst,start,end, Nt = length(sst[,1]))[length(sst[,1]),1]

	}




	studies_var

}

#H.T.A.

hma_sign <- function(hma){
	sign <- hma
	l <- length(hma)
	for(i in 24:l){
		if(hma[i]>hma[i-1]){sign[i]=1}
		else{sign[i]=0}
	}
	sign
}
tether <- function(HL,t=50){
	l=length(HL[,1])
	tether <- c()
	for(i in 51:l){
		high <- max(HL[(i-t):i,1])
		low <- min(HL[(i-t):i,2])
		tether[i] <- (high+low)/2
		#print(c(high,low,tether[i],serie[i],i,(i-t)))
		
	}
	tether
}
HTA_signal <- function(name, length_sample, tt_t=25, hma_n=20, adx_n=14){
	
	library(tseries)
	library(zoo)
	library(TTR)
	print("check")
	data_OHLC <- get.hist.quote(name)
	end <- length(data_OHLC[,4])
	start <- end-(length_sample)
	
	print("check")
	
	data_hma <- HMA(data_OHLC[,4],n=hma_n)
	data_hma_sign <- hma_sign(data_hma)
	data_adx <- ADX(cbind(data_OHLC[,2],data_OHLC[,3],data_OHLC[,4]),n=adx_n)
	data_tt <- tether(cbind(data_OHLC[,2],data_OHLC[,3]),t=tt_t)
	
	print("check")
	data <- cbind(data_OHLC[,4],data_hma,data_hma_sign,data_adx[,4],data_tt)
	
	up_signals <- c()
	up_c <- 1
	sell_signals <- c()
	sell_c <- 1
	down_signals <- c()
	down_c <- 1
	buy_signals <- c()
	buy_c <- 1
	
	#aggiunto che anche giorno di entrata il prezzo deve essere sopra teth
	
	
	
	for(t in start:end){
		if(data[(t-1),5]>data[(t-1),1] && data[t,5]<data[t,1] && data[(t+1),5]<data[(t+1),1] && data[t,4]>20){
			if(data[t,3]==1){ #no delta HMA
				#up_signal
				up_signals[up_c] <- t
				up_c <- up_c+1
				flag_up=1
				for(tt in t:end){
					#print(cbind(tt,data[(tt-1),5],data[(tt-1),1]))  CHECK
					if(data[(tt-1),5]<data[(tt-1),1] && data[tt,5]>data[tt,1] && flag_up==1){
						#quit
						sell_signals[sell_c] <- tt
						sell_c <- sell_c+1
						flag_up <- 0
					}
				}
			}
		}
		if(data[(t-1),5]<data[(t-1),1] && data[t,5]>data[t,1] && data[(t+1),5]>data[(t+1),1] && data[t,4]>20){
			if(data[t,3]==0){  #no delta HMA
				#down_signal
				down_signals[down_c] <- t
				down_c <- down_c+1
				flag_down=1
				for(tt in t:end){
					if(data[(tt-1),5]>data[(tt-1),1] && data[tt,5]<data[tt,1] && flag_down==1){
						#quit
						buy_signals[buy_c] <- tt
						buy_c <- buy_c+1
						flag_down <- 0
					}
				}
			}
		}
	}	
	
	cbind(up_signals, sell_signals, down_signals, buy_signals)
}
date_sign <- function(serie,sign,mode){
	date_sign_first <- time(serie)[sign[1,mode]]
	date_sign <- c(date_sign_first)
	for(i in 2:length(sign[,mode])){
		date_sign[i]=time(serie)[sign[i,mode]]
		#print(date_sign[i])
	}
	date_sign
}
proceed <- function(serie,HTA_sign){
	
	sign_up <- c(date_sign(serie,HTA_sign,1),as.Date("3000-01-01"))
	#print(sign_up)
	count_up <- 1
	sign_sell <- c(date_sign(serie,HTA_sign,2),as.Date("3000-01-01"))
	sign_down <- c(date_sign(serie,HTA_sign,3),as.Date("3000-01-01"))
	#print(sign_down)
	count_down <- 1
	sign_buy <- c(date_sign(serie,HTA_sign,4),as.Date("3000-01-01"))

	output <- c(1)
	count_out <- 1
	
	for(i in 1:(4*length(sign_up))){
		
			if(sign_up[count_up]<sign_down[count_down]){	
				if(count_up==1 || HTA_sign[count_up,1]>HTA_sign[(count_up-1),1]){
				
				ss <- as.numeric(serie[HTA_sign[count_up,1]+1,1])
				print("OPEN POSITION - buy")
				print(sign_up[count_up]) #trigger's date
				print(ss) #open of the next day
				
				ee <- as.numeric(serie[HTA_sign[count_up,2]+1,1])
				print("CLOSE POSITION - sell")
				print(sign_sell[count_up])
				print(ee)
				
				
				
				
				output[count_out] <- (ee-ss)/ss
				print(output[count_out])
				
		
		
				count_out <- count_out+1
				count_up <- count_up+1
				
				print("---------------")
				
				}
				else{ count_up = length(sign_up) }
			}
			
			if(sign_down[count_down]<sign_up[count_up]){
				if(count_down==1 || HTA_sign[count_down,3]>HTA_sign[(count_down-1),3]){
					
				ss <- as.numeric(serie[HTA_sign[count_down,3]+1,1])	
				print("OPEN POSITION - sell")
				print(sign_down[count_down])
				print(ss)
				
				ee <- as.numeric(serie[HTA_sign[count_down,4]+1,1])
				print("CLOSE POSITION - buy")
				print(sign_buy[count_down])
				print(ee)			
				
				
				
				
				output[count_out] <- (ss-ee)/ss
				print(output[count_out])
				
				count_out <- count_out+1
				count_down <- count_down+1
				
				
				print("---------------")

				
			}
				else{ count_down = length(sign_down) }
			}
	
	}
	
	
	output

}
count_date <- function(sst, date = "0000-00-00"){
	lll <- length(time(sst))
	for(i in 1:lll){
		if(as.Date(time(sst)[i])==date){
			num <- i	
		}
	}
	num
}
var_to_cap <- function(VaR,cap_max,cap_med,var_med=0.2){
 	cap <- cap_max - ((cap_max-cap_med)/(var_med))*VaR
	cap
}
clean_date <- function(date_up,date_down){
	date <- c(date_up,date_down)
	date <- sort(date)
	date <- c(date,as.Date("2020-01-01"):as.Date("2021-01-01"))
	#eliminate duplicates
	l <- length(date_up)+length(date_down)
	for(i in 1:l){
		#print(date)
		#print(i)
		#print(l)
		if(date[i+1]==date[i]){
			for(j in i:(2*l)){
				date[j] <- date[j+1]
			}
			l <- l-1
		}
		#print("check")
	}
	date <- date[1:l]
	date
}


interest <- function(perc,mode=1,yinf=0.5,ysup=1.5,title="Backtest",plot=TRUE, end_delta=130, sst_closure, hta_signals, cap=1000, cap_med_fact=0.7, n_mean){
	if(mode==1){
		li <- sum(perc)
		if(plot==TRUE){
			plot(cumsum(perc),type='l',ylab="variation",xlab="time",main=title)
			}	
		return(li)
		}
		
	if(mode==2){
		capt <- c(cap)
		for(i in 1:length(perc)){capt[i+1] <- capt[i]*(1+perc[i])}
		if(plot==TRUE){
			plot(x=c(1:length(capt)),y=capt, type='l', ylim=c(yinf*cap,ysup*cap), ylab="capital", xlab="time",main=title)
			}
		return(capt)
		}
		
	if(mode==3){       # <- EWMA_RiskMetrics()®
	
		capt <- c(cap)
		print("getting cleaned date signals")
		date_signals <- clean_date(date_sign(sst_closure,hta_signals,1),date_sign(sst_closure,hta_signals,3))
		
		for(i in 1:length(perc)){
			print("starting calc new position for")
			print(perc[i])
			print(date_signals[i])
			day_numeric <- count_date(sst_closure, date_signals[i])
			print(day_numeric)
			
			print("getting VaR serie")
			sst_study <- study(serie=as.timeSeries(sst_closure),start="1900-01-01", end= time(sst_closure)[day_numeric-end_delta],  N_day = day_numeric)
			print("calc var")
			print(head(sst_study))
			print(tail(sst_study))
			var <- sst_study[length(sst_study[,1]),1]
			
			print("calc mean_var")
			mean_with_na <- sst_study[(length(sst_study[,1])-n_mean):length(sst_study[,1]),1]
			var_mean <- mean(mean_with_na[!is.na(mean_with_na)])
			
			print(var)
			print(var_mean)
			
			print("capital accounting")
			cap_invest <- as.numeric(var_to_cap(VaR=var,cap_max=capt[i],cap_med=cap_med_fact*capt[i],var_med=var_mean))
			cap_left <- capt[i]-cap_invest
			capt[i+1] <- cap_left+cap_invest*(1+perc[i])
			
			
			
			print(cap_invest)
			print(cap_left)
			print(capt[i+1])
			print("---------")
			
			}
			
		if(plot==TRUE){
			plot(x=c(1:length(capt)),y=capt, type='l', ylim=c(yinf*cap,ysup*cap), ylab="capital", xlab="time",main=title)
			}
		return(capt)
	
	}
}

trade <- function(name, l=500, tit="BACKTEST", plot=TRUE,capital=1000,cap_med_fact=0.7 ,n_mean=100){
	print("starting to trade")
	library(tseries)
	print("getting prices")
	stock <- get.hist.quote(name)
	print("calc HTA_signals")
	stock_hta <- HTA_signal(name, l)
	print("calc variations in prices from signal to signal")
	stock_r <- proceed(stock,stock_hta)
	print("calc interest with capital risk modulation")
	stock_p <- interest(stock_r,3,end_delta=150,sst_closure=stock[,4],hta_signals=stock_hta,cap=capital,cap_med_fact=cap_med_fact, n_mean=n_mean, plot=plot)
	print("done")
	stock_p
}
trade_basket <- function(titoli,l,single_plot=FALSE,fact=0.8){
	
	basket <- c(trade(titoli[1],l,plot=FALSE))
	earnings <- c()
	count_earnings <- 1
	plot(basket,xlab="time",ylab="variations",main="basket backtesting",type="l",ylim=c(400,1600),xlim=c(1,30))
	for(i in 2:length(titoli)){
		new_tit <- trade(titoli[i],l,plot=FALSE,cap_med_fact=fact)
		new_tit <- new_tit[!is.na(new_tit)]
		lines(new_tit)
		basket[i] <- new_tit
		earnings[count_earnings] <- new_tit[length(new_tit)]
		count_earnings <- count_earnings+1
		
	}
	
	earnings

	
}










#note:
# 06/08/2016
# VaR medio in realtà non cambia molto fra 10 100 1000, migliore sembra 100
# per ora il backtesting vabene, non eccellente però -> aumentare rischio factor 0.7 -> 0.9
# non si sono ancora viste serie storiche concluse con >+10% profit
# VaR per ora sembra abbastanza inutile <- effetiv_VaR
# end_delta VERIFICARE SE CAMBIA

# 05/08/2016
# come calcolare il VaR medio? ha senso l'esponenziale o meglio lineare per VaR to cap?
#VaR medio su periodo lungo (1000) ottimo per investimenti di lungo periodo <- se cumulativi
#attenzione NA in certi VaR sugli ultimi (?) don'tknow why yet
# con un VaR di lungo periodo (basso) si evita a prescindere alte volatilità <- 
#quindi si evitano perdite a frustata che rovinano il profitto cumulativo
#TESTARE QUESTA IPOTESI PERO
