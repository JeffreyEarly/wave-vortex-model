classdef ThermalObservationModel < WVModel
    % Exercise the real integration sampler without claiming stream restart.
    properties
        sampleInterval = Inf
        sampleTimes = []
        sampleStates = {}
    end
    methods
        function self=ThermalObservationModel(w), self@WVModel(w); end
        function times=outputTimesForIntegrationPeriod(self,t0,t1)
            times=unique([t0,t0+self.sampleInterval:self.sampleInterval:t1,t1]);
        end
        function writeTimeStepToNetCDFFile(self,t)
            self.sampleTimes(end+1)=t;
            self.sampleStates{end+1}=self.wvt.coefficientState();
        end
    end
end
