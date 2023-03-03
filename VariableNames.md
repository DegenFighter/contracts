ZKSync uses the space 2^16
so we should use 100000 and above


Should tests always be written in a way where we are testing against a prod deployment? 
For example, if we want to test ownership against prod
Fork prod chain
Get owner(), 
Do the check - compare owner to expected owner. Who is the expected owner? In the case of testing prod, the owner could've changed.
When there is a change to ownership, is this being recorded somewhere in a way that we should validate?




Move initialization of chain dependent data to Base 