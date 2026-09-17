import { calculateConsumption, calculateSlab, multiplyToMoney, moneyFromMinor, sumMoney } from "lib/billing.js";

export function runBillingUnitTests(){
 const out=[]; const eq=(name,a,b)=>{if(String(a)!==String(b))throw new Error(`${name}: expected ${b}, got ${a}`);out.push(name)};
 eq('consumption 12680-12450',calculateConsumption('12450','12680').consumption,'230.000');
 eq('money multiplication',multiplyToMoney('230.000',3,'8.0000',4),'1840.00');
 eq('sum money',sumMoney(['12000.00','1840.00','300.00']),'14140.00');
 eq('progressive slabs',calculateSlab('230.000',[{min_units:'0',max_units:'100',rate_per_unit:'5',fixed_charge:'0'},{min_units:'100',max_units:'200',rate_per_unit:'7',fixed_charge:'0'},{min_units:'200',max_units:null,rate_per_unit:'10',fixed_charge:'0'}]).amount,'1200.00');
 let invalid=false;try{calculateConsumption('200','199.999')}catch(e){invalid=e.code==='INVALID_METER_READING'}if(!invalid)throw new Error('lower current reading must fail');out.push('lower reading rejected');
 let overlap=false;try{calculateSlab('100',[{min_units:'0',max_units:'100',rate_per_unit:'5'},{min_units:'50',max_units:'150',rate_per_unit:'7'}])}catch(e){overlap=e.code==='INVALID_SLABS'}if(!overlap)throw new Error('overlapping slabs must fail');out.push('overlapping slabs rejected');
 eq('minor formatting',moneyFromMinor(914000),'9140.00');
 return {passed:out.length,tests:out};
}